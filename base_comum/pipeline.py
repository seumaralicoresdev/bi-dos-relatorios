"""Snapshots locais transacionais, cache de leitura e controle de fontes."""
from collections import Counter,defaultdict
from contextlib import contextmanager
from dataclasses import asdict,dataclass
from datetime import datetime,timezone
from decimal import Decimal
from pathlib import Path
import hashlib,itertools,json,math,os,re,shutil,time,uuid

import pyarrow as pa
import pyarrow.parquet as pq
from .aggregate import summarize_partition
from .catalog import COMPANIES,REPORTS,get_spec,infer_report,infer_delivery_month,validate_month
from .xlsx import read_workbook

NORMALIZER_VERSION='1'
# Layout de Desconto v2 distingue o total auxiliar do cabeçalho da tabela.
# A versão por família invalida somente as leituras afetadas pela correção.
NORMALIZER_VERSIONS={'desconto_tarifario':'2'}
BATCH_SIZE=20000


@dataclass(frozen=True)
class InputFile:
    path:Path
    report_id:str|None=None
    delivery_month:str|None=None
    part_number:int|None=None
    parts_total:int|None=None


def _json(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    with path.open('w',encoding='utf-8') as stream:
        json.dump(value,stream,ensure_ascii=False,indent=2,allow_nan=False)
        stream.write('\n')


def _file_hash(path):
    digest=hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda:stream.read(1024*1024),b''):digest.update(block)
    return digest.hexdigest()


def _key(value):
    return hashlib.sha256(json.dumps(value,ensure_ascii=False,sort_keys=True,default=str).encode()).hexdigest()


def _part_number(source,sheet_name=None):
    if source.part_number is not None:
        if source.part_number<1:raise ValueError('Número de parte deve ser positivo.')
        return source.part_number
    for name in (sheet_name or '',source.path.stem):
        match=re.search(r'(?:PARTE|PART|MODICIDAD)[ _-]*(\d+)(?!\d)',name.upper())
        if match:return int(match.group(1))
    return None


@contextmanager
def _lock(output):
    path=output/'.build.lock'
    try:fd=os.open(path,os.O_CREAT|os.O_EXCL|os.O_WRONLY,0o600)
    except FileExistsError:raise ValueError('Já existe processamento ou lock pendente nesta saída. Confira antes de remover .build.lock.') from None
    try:
        os.write(fd,str(os.getpid()).encode());os.close(fd)
        yield
    finally:path.unlink(missing_ok=True)


def _arrow_schema(headers,spec):
    fields=[pa.field(h,pa.float64() if h in spec.number_fields else pa.string()) for h in headers]
    fields.extend(pa.field(h,pa.string()) for h in ('__empresa','__competencia_remessa','__periodo_dados','__source_file','__source_sheet'))
    fields.append(pa.field('__source_row',pa.int64()))
    return pa.schema(fields)


def _arrow_row(row,spec):
    converted=dict(row)
    for name in spec.number_fields:
        if name in converted and converted[name] is not None:
            value=float(converted[name])
            if not math.isfinite(value):raise ValueError(f'Valor fora da capacidade numérica em {name}.')
            converted[name]=value
    return converted


def _row_hash(row,headers):
    values=[]
    for h in headers:
        value=row.get(h)
        if isinstance(value,Decimal):value={'number':str(value.normalize())}
        values.append((h,value))
    return hashlib.sha256(json.dumps(values,ensure_ascii=False,separators=(',',':'),sort_keys=True).encode()).digest()


def _cache_book(source,report_id,month,output,progress):
    spec=get_spec(report_id);fingerprint=_file_hash(source.path)
    version=NORMALIZER_VERSIONS.get(report_id,NORMALIZER_VERSION)
    cache_id=_key([version,fingerprint,report_id,month,asdict(spec)])
    folder=output/'.cache/books'/cache_id
    meta=folder/'metadata.json'
    if meta.exists():
        saved=json.loads(meta.read_text(encoding='utf-8'))
        if all((folder/s['parquet']).is_file() and (folder/s['hashes']).is_file() for s in saved['sheets']):
            return [{**s,'cache_folder':str(folder),'source_file':source.path.name} for s in saved['sheets']],True
    folder.mkdir(parents=True,exist_ok=True)
    progress(f'Lendo {source.path.name}')
    sheets=[]
    for index,(info,rows) in enumerate(read_workbook(source.path,report_id,month)):
        parquet_name=f'sheet{index}.parquet';hash_name=f'sheet{index}.sha256'
        target=folder/parquet_name;hash_target=folder/hash_name
        schema=_arrow_schema(info.headers,spec)
        writer=pq.ParquetWriter(target,schema,compression='zstd',use_dictionary=True)
        count=0;hash_sum=0;batch=[]
        try:
            with hash_target.open('wb') as hashes:
                for row in rows:
                    digest=_row_hash(row,info.headers)
                    hashes.write(digest)
                    hash_sum=(hash_sum+int.from_bytes(digest,'big'))%(1<<256)
                    batch.append(_arrow_row(row,spec));count+=1
                    if len(batch)>=BATCH_SIZE:
                        writer.write_table(pa.Table.from_pylist(batch,schema=schema));batch.clear()
                if batch:writer.write_table(pa.Table.from_pylist(batch,schema=schema))
        finally:writer.close()
        sheets.append({'sheet':info.name,'company':info.company,'headers':list(info.headers),
                       'rows':count,'row_hash_sum':hex(hash_sum),'parquet':parquet_name,'hashes':hash_name,
                       'source_hash':fingerprint,'book_cache_id':cache_id})
        progress(f'  {info.name}: {count:,} linhas')
    if not sheets:raise ValueError(f'{source.path.name}: nenhuma aba com cabeçalho foi encontrada.')
    if _file_hash(source.path)!=fingerprint:
        raise ValueError(f'{source.path.name}: arquivo alterado durante a leitura. Feche/salve a origem e execute novamente.')
    _json(meta,{'sheets':sheets})
    return [{**s,'cache_folder':str(folder),'source_file':source.path.name} for s in sheets],False


def _hashes(sheet):
    path=Path(sheet['cache_folder'])/sheet['hashes']
    with path.open('rb') as stream:
        while digest:=stream.read(32):
            if len(digest)!=32:raise ValueError('Cache de assinaturas incompleto.')
            yield digest


def _same_rows(a,b):
    if any(a[k]!=b[k] for k in ('headers','rows','row_hash_sum')):return False
    return Counter(_hashes(a))==Counter(_hashes(b))


def _select_group(candidates):
    selected=[];duplicates=[]
    for candidate in candidates:
        duplicate=next((s for s in selected if _same_rows(candidate,s)),None)
        if duplicate:
            duplicates.append({'source_file':candidate['source_file'],'sheet':candidate['sheet'],
                               'same_as':duplicate['source_file'],'rows_excluded':candidate['rows']})
        else:selected.append(candidate)
    if len(selected)>1:
        parts=[s['part_number'] for s in selected]
        if None in parts or len(parts)!=len(set(parts)):
            raise ValueError('Mais de uma versão distinta para a mesma entrega sem partes distintas. Mantenha apenas a versão aprovada ou declare partes.')
        if len({tuple(s['headers']) for s in selected})!=1:raise ValueError('Partes da mesma entrega têm cabeçalhos diferentes.')
    # Repetições internas de uma fonte são preservadas. Sobreposição entre partes não é descartada silenciosamente.
    seen=set()
    for part in selected:
        current=set(_hashes(part))
        if seen & current:raise ValueError('Partes têm linhas inteiras sobrepostas. Confira os limites da divisão.')
        seen.update(current)
    part_numbers={s['part_number'] for s in selected if s['part_number'] is not None}
    totals={s['parts_total'] for s in selected if s['parts_total'] is not None}
    if len(totals)>1:raise ValueError('Totais de partes conflitantes para a mesma entrega.')
    if totals:
        total=next(iter(totals))
        if total<1 or part_numbers-set(range(1,total+1)):raise ValueError('Parte fora do total declarado.')
        partial=part_numbers!=set(range(1,total+1))
    else:partial=bool(part_numbers)
    return selected,duplicates,partial


def _link_or_copy(source,target):
    target.parent.mkdir(parents=True,exist_ok=True)
    try:os.link(source,target)
    except OSError:shutil.copy2(source,target)


def _group_cache(selected,report_id,company,month,output,progress):
    spec=get_spec(report_id)
    version=NORMALIZER_VERSIONS.get(report_id,NORMALIZER_VERSION)
    signature=_key([version,report_id,company,month,asdict(spec),
                    sorted((s['book_cache_id'],s['sheet'],s['source_file']) for s in selected)])
    folder=output/'.cache/groups'/signature
    target=folder/'dados.parquet';summary_path=folder/'summary.json'
    if target.exists() and summary_path.exists():
        return target,json.loads(summary_path.read_text(encoding='utf-8')),True
    folder.mkdir(parents=True,exist_ok=True)
    progress(f'Consolidando {report_id}/{month}/{company}')
    first=pq.ParquetFile(Path(selected[0]['cache_folder'])/selected[0]['parquet'])
    schema=first.schema_arrow
    writer=pq.ParquetWriter(target,schema,compression='zstd',use_dictionary=True)
    try:
        for source in selected:
            parquet=pq.ParquetFile(Path(source['cache_folder'])/source['parquet'])
            if parquet.schema_arrow!=schema:raise ValueError('Tipos diferentes em partes da mesma entrega.')
            for batch in parquet.iter_batches(batch_size=65536):
                column=schema.get_field_index('__source_file')
                batch=batch.set_column(column,schema.field(column),
                                       pa.array([source['source_file']]*batch.num_rows,type=pa.string()))
                writer.write_batch(batch)
    finally:writer.close()
    summary=summarize_partition([target],report_id=report_id,company=company,delivery_month=month,
                                metrics=spec.metrics,dimensions=spec.dimensions)
    _json(summary_path,summary)
    return target,summary,False


def build_base(inputs:list[InputFile],output:Path,progress=None):
    """Recompõe o snapshot a partir do conjunto selecionado, reutilizando fontes sem alteração."""
    progress=progress or (lambda message:None)
    output=Path(output).resolve();output.mkdir(parents=True,exist_ok=True)
    if not inputs:raise ValueError('Nenhum arquivo de entrada foi selecionado.')
    started=time.monotonic()
    with _lock(output):
        grouped=defaultdict(list);months=set();files_read=0;book_cache_hits=0
        for raw in inputs:
            source=InputFile(Path(raw.path).resolve(),raw.report_id,raw.delivery_month,raw.part_number,raw.parts_total)
            report_id=source.report_id or infer_report(source.path.name)
            get_spec(report_id)
            month=validate_month(source.delivery_month) if source.delivery_month else infer_delivery_month(source.path)
            months.add(month)
            sheets,cached=_cache_book(source,report_id,month,output,progress)
            files_read+=not cached;book_cache_hits+=cached
            for sheet in sheets:
                grouped[report_id,month,sheet['company']].append({**sheet,'part_number':_part_number(source,sheet['sheet']),'parts_total':source.parts_total})
        snapshot_id=datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')+'_'+uuid.uuid4().hex[:12]
        snapshot=output/'snapshots'/snapshot_id;snapshot.mkdir(parents=True)
        coverage=[];web={d:[] for d in ('contabilidade','tributario')};duplicates=[];rows_total=0;group_cache_hits=0
        try:
            for report_id,month,company in itertools.product(REPORTS,sorted(months),COMPANIES):
                spec=get_spec(report_id);candidates=grouped.get((report_id,month,company),[])
                if not candidates:
                    status='aguardando_arquivo_separado';count=None;sources=[]
                    summary={'report_id':report_id,'company':company,'delivery_month':month,'rows':None,
                             'metrics':{name:{'value':None,'observed_rows':0} for name in spec.metrics},'breakdowns':{}}
                else:
                    selected,repeated,partial=_select_group(candidates)
                    duplicates.extend({**x,'report_id':report_id,'company':company,'delivery_month':month} for x in repeated)
                    target,summary,cached=_group_cache(selected,report_id,company,month,output,progress)
                    group_cache_hits+=cached
                    count=summary['rows'];rows_total+=count
                    status=('partes_recebidas_cobertura_nao_confirmada' if partial else
                            'arquivo_recebido' if count else 'arquivo_recebido_sem_registros')
                    sources=[{'file':s['source_file'],'sheet':s['sheet'],'sha256':s['source_hash'],
                              'part_number':s['part_number'],'parts_total':s['parts_total'],'rows':s['rows']} for s in selected]
                    _link_or_copy(target,snapshot/'parquet'/spec.domain/report_id/month/company/'dados.parquet')
                coverage.append({'domain':spec.domain,'report_id':report_id,'delivery_month':month,'company':company,
                                 'status':status,'rows':count,'sources':sources})
                web[spec.domain].append({**summary,'status':status})
            _json(snapshot/'coverage.json',{'schema_version':1,'entries':coverage,
                                           'duplicates_excluded':duplicates,'missing_is_zero':False})
            for domain,partitions in web.items():
                _json(snapshot/'web'/f'{domain}.json',{'schema_version':1,'domain':domain,'partitions':partitions,
                    'classification':'corporativo_privado','note':'Agregações não representam autorização de publicação nem conciliação financeira.'})
            summary={'schema_version':1,'snapshot':str(snapshot.relative_to(output)).replace(os.sep,'/'),
                     'files_read':int(files_read),'book_cache_hits':int(book_cache_hits),'group_cache_hits':int(group_cache_hits),
                     'rows':rows_total,'duplicate_sheets':len(duplicates),
                     'coverage_counts':dict(Counter(x['status'] for x in coverage)),
                     'duration_seconds':round(time.monotonic()-started,3)}
            _json(snapshot/'run.json',summary)
            pointer=output/('.current_'+uuid.uuid4().hex+'.tmp')
            _json(pointer,{'schema_version':1,'snapshot':summary['snapshot']})
            os.replace(pointer,output/'current.json')
            return summary
        except Exception:
            # Só o candidato desta execução é removido; o snapshot ativo permanece intacto.
            shutil.rmtree(snapshot,ignore_errors=True)
            raise
