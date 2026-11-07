"""Leitor XLSX streaming: dados originais nunca são sobrescritos."""
from dataclasses import dataclass
from datetime import datetime,timedelta
from decimal import Decimal,InvalidOperation
from pathlib import Path
import posixpath,re,zipfile
from lxml import etree as E
from .catalog import COMPANIES,get_spec,normalize_header,validate_month

NS='http://schemas.openxmlformats.org/spreadsheetml/2006/main'
T='{'+NS+'}'
R='{http://schemas.openxmlformats.org/officeDocument/2006/relationships}'


@dataclass(frozen=True)
class SheetInfo:
    name:str
    company:str
    headers:tuple[str,...]


def _xml(data):
    return E.fromstring(data,parser=E.XMLParser(resolve_entities=False,no_network=True))


def _clear(node):
    node.clear()
    while node.getprevious() is not None:del node.getparent()[0]


def _strings(z):
    values=[]
    if 'xl/sharedStrings.xml' not in z.namelist():return values
    with z.open('xl/sharedStrings.xml') as stream:
        for _,n in E.iterparse(stream,events=('end',),tag=T+'si',resolve_entities=False,no_network=True):
            values.append(''.join(x.text or '' for x in n.iter(T+'t')));_clear(n)
    return values


def _column(reference):
    index=0
    for ch in reference:
        if 'A'<=ch<='Z':index=index*26+ord(ch)-64
        else:break
    return index-1


def _formats(z):
    if 'xl/styles.xml' not in z.namelist():return {}
    tree=_xml(z.read('xl/styles.xml'))
    custom={int(n.get('numFmtId')):n.get('formatCode','') for n in tree.findall('.//'+T+'numFmt')}
    xfs=tree.find(T+'cellXfs')
    if xfs is None:return {}
    return {i:(int(n.get('numFmtId','0')),custom.get(int(n.get('numFmtId','0')),'')) for i,n in enumerate(xfs)}


def _value(cell,strings,formats,date1904):
    kind=cell.get('t','n');v=cell.find(T+'v');raw=v.text if v is not None else None
    if cell.find(T+'f') is not None and raw is None:
        raise ValueError('Fórmula sem resultado em cache; recalcular o arquivo no Excel antes de importar.')
    if kind=='e':raise ValueError('Célula com erro Excel; corrigir a origem antes de importar.')
    if kind=='s':return strings[int(raw)] if raw is not None else None
    if kind=='inlineStr':return ''.join(t.text or '' for t in cell.iter(T+'t'))
    if raw is None:return None
    if kind in ('str','d'):return raw
    if kind=='b':return raw=='1'
    try:number=Decimal(raw)
    except InvalidOperation:raise ValueError('Célula numérica inválida.') from None
    if not number.is_finite():raise ValueError('Número não finito na planilha.')
    fmt,pattern=formats.get(int(cell.get('s','0')),(0,''))
    is_date=fmt in set(range(14,23))|{45,46,47} or bool(re.search(r'(?i)(?:yy|dd)',re.sub(r'"[^"]*"','',pattern)))
    if is_date:
        origin=datetime(1904,1,1) if date1904 else datetime(1899,12,30)
        return (origin+timedelta(days=float(number))).isoformat(timespec='seconds')
    if re.fullmatch(r'0{2,}',pattern) and number==number.to_integral_value():
        return str(int(number)).zfill(len(pattern))
    return number


def _text(value):
    if value is None or value=='':return None
    if isinstance(value,Decimal):return format(value,'f')
    if isinstance(value,bool):return '1' if value else '0'
    return str(value).strip()


def _number(value):
    if value is None or value=='':return None
    if isinstance(value,Decimal):number=value
    else:
        text=str(value).strip().replace('\u00a0','').replace(' ','')
        if ',' in text:text=text.replace('.','').replace(',','.')
        try:number=Decimal(text)
        except InvalidOperation:raise ValueError('Texto numérico inválido em campo de medida.') from None
    if not number.is_finite():raise ValueError('Medida numérica não finita.')
    return number


def _company(value):
    n=normalize_header(value)
    for company in COMPANIES:
        uf=company[5:]
        if n in (company,uf,'CCS_'+uf) or n.startswith(company+'_'):return company
    return None


def _row_stream(z,target,strings,formats,date1904):
    with z.open(target) as stream:
        for _,node in E.iterparse(stream,events=('end',),tag=T+'row',resolve_entities=False,no_network=True):
            try:
                values={_column(c.get('r','')):_value(c,strings,formats,date1904) for c in node.findall(T+'c')}
                if any(v is not None and v!='' for v in values.values()):
                    yield int(node.get('r','0')),values
            except ValueError as exc:
                raise ValueError(f'Linha {node.get("r","?")}: {exc}') from None
            finally:_clear(node)


def read_workbook(path,report_id,delivery_month):
    """Consumir cada iterador de linhas antes de avançar para a próxima aba."""
    path=Path(path);spec=get_spec(report_id);delivery_month=validate_month(delivery_month)
    with zipfile.ZipFile(path) as z:
        strings=_strings(z);formats=_formats(z)
        wb=_xml(z.read('xl/workbook.xml'))
        props=wb.find(T+'workbookPr');date1904=props is not None and props.get('date1904') in ('1','true')
        relationships=_xml(z.read('xl/_rels/workbook.xml.rels'))
        targets={n.get('Id'):n.get('Target') for n in relationships if n.get('TargetMode')!='External'}
        for sheet in wb.findall('.//'+T+'sheet'):
            name=sheet.get('name');target=targets.get(sheet.get(R+'id'))
            if not target:raise ValueError(f'Aba {name}: worksheet interna ausente.')
            target=target.lstrip('/') if target.startswith('/') else posixpath.normpath('xl/'+target)
            if not target.startswith('xl/') or '..' in target.split('/'):raise ValueError('Caminho XLSX inválido.')
            stream=_row_stream(z,target,strings,formats,date1904)
            first=next(stream,None)
            if first is None:continue
            _,raw_headers=first
            width=max(raw_headers)+1
            trimmed_auxiliary=False
            # Desconto pode trazer um total auxiliar à direita do cabeçalho,
            # separado da tabela por colunas vazias (ex.: tabela A:O, total R1).
            # Só reconhecer a cauda numérica desse layout; dados nela são erro.
            if report_id=='desconto_tarifario':
                gap=next((i for i in range(width) if _text(raw_headers.get(i)) is None),None)
                if gap is not None and gap>0:
                    tail=[v for i,v in raw_headers.items() if i>gap and _text(v) is not None]
                    if tail and all(isinstance(v,Decimal) for v in tail):
                        width=gap;trimmed_auxiliary=True
            headers=[normalize_header(raw_headers.get(i,'')) or f'COLUNA_{i+1}' for i in range(width)]
            if report_id=='consumo_proprio' and headers.count('NUMERO')==2:
                indices=[i for i,h in enumerate(headers) if h=='NUMERO']
                headers[indices[0]]='NUMERO_FATURA';headers[indices[1]]='NUMERO_ENDERECO'
            if len(headers)!=len(set(headers)):raise ValueError(f'Aba {name}: cabeçalhos repetidos sem regra de resolução.')
            if set(headers)&{'__EMPRESA','__COMPETENCIA_REMESSA','__PERIODO_DADOS','__SOURCE_FILE','__SOURCE_SHEET','__SOURCE_ROW'}:
                raise ValueError('Cabeçalho usa nome reservado.')
            missing=spec.required-set(headers)
            if missing:raise ValueError(f'Aba {name}: colunas obrigatórias ausentes: {sorted(missing)}')
            first_data=next(stream,None)
            company=_company(name)
            if company is None and first_data:
                values=first_data[1]
                for field in ('EMPRESA','ESTADO','DISTRIBUIDORA'):
                    if field in headers:
                        company=_company(_text(values.get(headers.index(field))))
                        if company:break
            if company is None:raise ValueError(f'Aba {name}: não foi possível identificar uma distribuidora válida.')
            info=SheetInfo(name,company,tuple(headers))

            def normalized(first_data=first_data,stream=stream,headers=headers,info=info,
                           trimmed_auxiliary=trimmed_auxiliary):
                import itertools
                initial=() if first_data is None else (first_data,)
                for rowno,values in itertools.chain(initial,stream):
                    if trimmed_auxiliary and any(i>=len(headers) and v is not None and v!='' for i,v in values.items()):
                        raise ValueError(f'{path.name}, aba {info.name}, linha {rowno}: dados fora da tabela na área de total auxiliar.')
                    row={}
                    for i,header in enumerate(headers):
                        try:row[header]=_number(values.get(i)) if header in spec.number_fields else _text(values.get(i))
                        except ValueError as exc:raise ValueError(f'{path.name}, aba {info.name}, linha {rowno}, coluna {header}: {exc}') from None
                    for field in ('EMPRESA','ESTADO','DISTRIBUIDORA'):
                        if field in row:
                            observed=_company(row[field])
                            if observed and observed!=info.company:raise ValueError(f'{path.name}, aba {info.name}, linha {rowno}: empresa divergente.')
                    period=None
                    if spec.period_column:
                        value=row[spec.period_column]
                        if value is not None:
                            try:period=validate_month(value)
                            except ValueError:raise ValueError(f'{path.name}, aba {info.name}, linha {rowno}: período inválido em {spec.period_column}.') from None
                    row.update(__empresa=info.company,__competencia_remessa=delivery_month,__periodo_dados=period,
                               __source_file=path.name,__source_sheet=info.name,__source_row=rowno)
                    yield row
            yield info,normalized()
