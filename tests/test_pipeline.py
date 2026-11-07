from pathlib import Path
from contextlib import redirect_stdout
import io,json,tempfile,unittest
import pyarrow.parquet as pq

from fixtures import modicidade,make_xlsx
from base_comum.pipeline import InputFile,build_base


class PipelineTests(unittest.TestCase):
    def _current(self,output):
        pointer=json.loads((output/'current.json').read_text())
        return output/pointer['snapshot']

    def _coverage(self,output):
        return json.loads((self._current(output)/'coverage.json').read_text())['entries']

    def test_missing_company_is_pending_with_null_and_never_zero(self):
        with tempfile.TemporaryDirectory() as d:
            d=Path(d);p=modicidade(d/'modicidade_202610.xlsx');out=d/'out'
            build_base([InputFile(p,'modicidade_tarifaria','202610')],out)
            rows=self._coverage(out)
            missing=next(x for x in rows if x['report_id']=='modicidade_tarifaria' and x['company']=='EQTL_PA')
            self.assertEqual(missing['status'],'aguardando_arquivo_separado')
            self.assertIsNone(missing['rows'])
            web=json.loads((self._current(out)/'web/contabilidade.json').read_text())
            entry=next(x for x in web['partitions'] if x['report_id']=='modicidade_tarifaria' and x['company']=='EQTL_PA')
            self.assertIsNone(entry['metrics']['VALOR']['value'])

    def test_rerun_uses_cache_and_correction_replaces_prior_amount(self):
        with tempfile.TemporaryDirectory() as d:
            d=Path(d);p=modicidade(d/'modicidade.xlsx');out=d/'out'
            source=[InputFile(p,'modicidade_tarifaria','202610')]
            first=build_base(source,out)
            self.assertEqual(first['files_read'],1)
            second=build_base(source,out)
            self.assertEqual(second['files_read'],0)
            modicidade(p,[['EQTL_MA','202610',25,'001','0153']])
            third=build_base(source,out)
            self.assertEqual(third['files_read'],1)
            parquet=self._current(out)/'parquet/contabilidade/modicidade_tarifaria/202610/EQTL_MA/dados.parquet'
            data=pq.ParquetFile(parquet).read().to_pydict()
            self.assertEqual(data['VALOR'],[25.0])

    def test_identical_rows_reordered_in_two_files_are_not_imported_twice(self):
        with tempfile.TemporaryDirectory() as d:
            d=Path(d);rows=[['EQTL_MA','202610',10,'001','0153'],['EQTL_MA','202610',20,'002','0153']]
            a=modicidade(d/'modicidade_a.xlsx',rows)
            b=modicidade(d/'modicidade_b.xlsx',list(reversed(rows)))
            out=d/'out'
            report=build_base([InputFile(a,'modicidade_tarifaria','202610'),InputFile(b,'modicidade_tarifaria','202610')],out)
            self.assertEqual(report['rows'],2)
            self.assertEqual(report['duplicate_sheets'],1)

    def test_split_parts_combine_and_partial_overlap_is_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            d=Path(d);a=modicidade(d/'modicidade_parte1.xlsx',[['EQTL_MA','202610',10,'001','0153']])
            b=modicidade(d/'modicidade_parte2.xlsx',[['EQTL_MA','202610',20,'002','0153']])
            out=d/'out';inputs=[InputFile(a,'modicidade_tarifaria','202610',parts_total=2),InputFile(b,'modicidade_tarifaria','202610',parts_total=2)]
            self.assertEqual(build_base(inputs,out)['rows'],2)
            old=(out/'current.json').read_bytes()
            modicidade(b,[['EQTL_MA','202610',10,'001','0153'],['EQTL_MA','202610',20,'002','0153']])
            with self.assertRaises(ValueError):build_base(inputs,out)
            self.assertEqual((out/'current.json').read_bytes(),old)

    def test_two_distinct_full_versions_are_not_silently_appended(self):
        with tempfile.TemporaryDirectory() as d:
            d=Path(d)
            a=modicidade(d/'modicidade_antigo.xlsx',[['EQTL_MA','202610',10,'001','0153']])
            b=modicidade(d/'modicidade_corrigido.xlsx',[['EQTL_MA','202610',25,'001','0153']])
            with self.assertRaises(ValueError):build_base([InputFile(a,'modicidade_tarifaria','202610'),InputFile(b,'modicidade_tarifaria','202610')],d/'out')

    def test_bad_new_file_does_not_replace_current_snapshot(self):
        with tempfile.TemporaryDirectory() as d:
            d=Path(d);p=modicidade(d/'modicidade.xlsx');out=d/'out'
            build_base([InputFile(p,'modicidade_tarifaria','202610')],out)
            before=(out/'current.json').read_bytes()
            p.write_bytes(b'arquivo danificado')
            with self.assertRaises(Exception):build_base([InputFile(p,'modicidade_tarifaria','202610')],out)
            self.assertEqual((out/'current.json').read_bytes(),before)

    def test_october_and_january_2027_coexist_when_both_sources_are_selected(self):
        with tempfile.TemporaryDirectory() as d:
            d=Path(d);a=modicidade(d/'modicidade_202610.xlsx')
            b=modicidade(d/'modicidade_202701.xlsx',[['EQTL_MA','202701',30,'001','0153']])
            out=d/'out';build_base([InputFile(a,'modicidade_tarifaria','202610'),InputFile(b,'modicidade_tarifaria','202701')],out)
            received=[x for x in self._coverage(out) if x['report_id']=='modicidade_tarifaria' and x['status']=='arquivo_recebido']
            self.assertEqual({x['delivery_month'] for x in received},{'202610','202701'})

    def test_empty_received_sheet_has_unavailable_amount_not_confirmed_zero(self):
        with tempfile.TemporaryDirectory() as d:
            d=Path(d);p=modicidade(d/'modicidade.xlsx',[]);out=d/'out'
            build_base([InputFile(p,'modicidade_tarifaria','202610')],out)
            row=next(x for x in self._coverage(out) if x['report_id']=='modicidade_tarifaria' and x['company']=='EQTL_MA')
            self.assertEqual(row['status'],'arquivo_recebido_sem_registros')
            web=json.loads((self._current(out)/'web/contabilidade.json').read_text())
            entry=next(x for x in web['partitions'] if x['report_id']=='modicidade_tarifaria' and x['company']=='EQTL_MA')
            self.assertIsNone(entry['metrics']['VALOR']['value'])

    def test_source_changed_after_hash_is_rejected_without_contaminating_cache(self):
        with tempfile.TemporaryDirectory() as d:
            d=Path(d);p=modicidade(d/'modicidade.xlsx');out=d/'out'
            source=[InputFile(p,'modicidade_tarifaria','202610')]
            build_base(source,out)
            before=(out/'current.json').read_bytes()
            modicidade(p,[['EQTL_MA','202610',11,'001','0153']])
            changed=False
            def alter(message):
                nonlocal changed
                if message.startswith('Lendo') and not changed:
                    changed=True
                    modicidade(p,[['EQTL_MA','202610',25,'001','0153']])
            with self.assertRaises(ValueError):build_base(source,out,progress=alter)
            self.assertEqual((out/'current.json').read_bytes(),before)
            modicidade(p,[['EQTL_MA','202610',11,'001','0153']])
            self.assertEqual(build_base(source,out)['files_read'],1)
            parquet=self._current(out)/'parquet/contabilidade/modicidade_tarifaria/202610/EQTL_MA/dados.parquet'
            self.assertEqual(pq.ParquetFile(parquet).read().to_pydict()['VALOR'],[11.0])

    def test_explicit_cli_delivery_month_overrides_filename_month(self):
        from base_comum.__main__ import main
        with tempfile.TemporaryDirectory() as d:
            d=Path(d);entrada=d/'entrada';entrada.mkdir()
            modicidade(entrada/'modicidade_202610.xlsx')
            out=d/'out'
            with redirect_stdout(io.StringIO()):
                code=main(['--input',str(entrada),'--delivery-month','202701','--output',str(out)])
            self.assertEqual(code,0)
            self.assertEqual({x['delivery_month'] for x in self._coverage(out)},{'202701'})

    def test_two_numbered_sheets_of_same_company_are_complementary_parts(self):
        with tempfile.TemporaryDirectory() as d:
            d=Path(d);headers=['EMPRESA','REFERENCIA','VALOR','CONTA_CONTRATO','OPERACAO']
            p=make_xlsx(d/'modicidade_PA.xlsx',{
                'EQTL_PA_MODICIDAD1':[headers,['EQTL_PA','202610',10,'001','0153']],
                'EQTL_PA_MODICIDAD2':[headers,['EQTL_PA','202610',20,'002','0153']]})
            out=d/'out'
            result=build_base([InputFile(p,'modicidade_tarifaria','202610',parts_total=2)],out)
            self.assertEqual(result['rows'],2)
            row=next(x for x in self._coverage(out) if x['report_id']=='modicidade_tarifaria' and x['company']=='EQTL_PA')
            self.assertEqual(row['status'],'arquivo_recebido')

    def test_renaming_unchanged_source_keeps_lineage_current_without_xlsx_reread(self):
        with tempfile.TemporaryDirectory() as d:
            d=Path(d);p=modicidade(d/'modicidade_original.xlsx');out=d/'out'
            build_base([InputFile(p,'modicidade_tarifaria','202610')],out)
            renamed=p.rename(d/'modicidade_aprovado.xlsx')
            result=build_base([InputFile(renamed,'modicidade_tarifaria','202610')],out)
            self.assertEqual(result['files_read'],0)
            target=self._current(out)/'parquet/contabilidade/modicidade_tarifaria/202610/EQTL_MA/dados.parquet'
            self.assertEqual(pq.ParquetFile(target).read().to_pydict()['__source_file'],['modicidade_aprovado.xlsx'])


if __name__=='__main__':unittest.main()
