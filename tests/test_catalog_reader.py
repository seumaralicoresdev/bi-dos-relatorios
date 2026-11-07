from pathlib import Path
from decimal import Decimal
import tempfile
import unittest

from fixtures import make_xlsx, modicidade
from base_comum.catalog import infer_report, get_spec, validate_month
from base_comum.xlsx import read_workbook


class CatalogReaderTests(unittest.TestCase):
    def test_infers_family_from_split_names_and_keeps_tusd_in_contabilidade(self):
        for name, want in [('EQTL_PA_MODICIDAD2.xlsx', 'modicidade_tarifaria'),
                           ('ICMS INJET RS.xlsx', 'icms_injetada'),
                           ('tusd_geradores_202701-ok.xlsx', 'tusd_geradores')]:
            self.assertEqual(infer_report(name), want)
        self.assertEqual(get_spec('tusd_geradores').domain, 'contabilidade')
        with self.assertRaises(ValueError): infer_report('arquivo_desconhecido.xlsx')

    def test_validates_future_months_without_hardcoded_year(self):
        self.assertEqual(validate_month('202701'), '202701')
        for value in ('202713', '202700', '2027', '2027-01'):
            with self.subTest(value=value), self.assertRaises(ValueError): validate_month(value)

    def test_reader_preserves_ids_and_parses_br_numbers_in_2027(self):
        with tempfile.TemporaryDirectory() as d:
            path = modicidade(Path(d)/'MODICIDADE TARIFARIA MA.xlsx',
                              [['EQTL_MA', '202701', '1.234,56', '0000123', '0153']])
            found=[]
            for info, rows in read_workbook(path, 'modicidade_tarifaria', '202701'):
                found.append((info, list(rows)))
            self.assertEqual(len(found), 1)
            info, rows = found[0]
            self.assertEqual(info.company, 'EQTL_MA')
            self.assertEqual(rows[0]['CONTA_CONTRATO'], '0000123')
            self.assertEqual(rows[0]['VALOR'], Decimal('1234.56'))
            self.assertEqual(rows[0]['__periodo_dados'], '202701')
            self.assertEqual(rows[0]['__competencia_remessa'], '202701')

    def test_split_sheet_uses_company_field_and_preserves_distinct_data_period(self):
        with tempfile.TemporaryDirectory() as d:
            p=modicidade(Path(d)/'EQTL_PA_MODICIDAD1.xlsx',
                         [['EQTL_PA','202609',-5,'001','0153']],sheet='EQTL_PA_MODICIDAD1')
            for info, rows in read_workbook(p,'modicidade_tarifaria','202610'):
                row=list(rows)[0]
                self.assertEqual(info.company,'EQTL_PA')
                self.assertEqual(row['__periodo_dados'],'202609')
                self.assertEqual(row['__competencia_remessa'],'202610')

    def test_conflicting_company_cannot_be_silently_assigned_by_sheet(self):
        with tempfile.TemporaryDirectory() as d:
            p=modicidade(Path(d)/'x.xlsx',[['EQTL_PA','202610',10,'001','0153']],sheet='EQTL_MA')
            with self.assertRaises(ValueError):
                for _, rows in read_workbook(p,'modicidade_tarifaria','202610'): list(rows)

    def test_duplicate_numero_headers_are_distinguished_by_role(self):
        with tempfile.TemporaryDirectory() as d:
            p=make_xlsx(Path(d)/'consumo_proprio_202610.xlsx',{'EQTL_MA':[
                ['EMPRESA','COMPETENCIA','NUMERO','NUMERO','VALOR_TOTAL','ICMS_TOTAL','BC_ICMS'],
                ['EQTL_MA','202610','00042','12',10,1,9]]})
            for info,rows in read_workbook(p,'consumo_proprio','202610'):
                data=list(rows)
                self.assertIn('NUMERO_FATURA',info.headers)
                self.assertIn('NUMERO_ENDERECO',info.headers)
                self.assertEqual(data[0]['NUMERO_FATURA'],'00042')
                self.assertEqual(data[0]['NUMERO_ENDERECO'],'12')

    def test_formula_without_cached_value_is_reported_instead_of_zero(self):
        with tempfile.TemporaryDirectory() as d:
            p=make_xlsx(Path(d)/'x.xlsx',{'EQTL_MA':[
                ['EMPRESA','REFERENCIA','VALOR'],['EQTL_MA','202610',None]]},
                formulas={('EQTL_MA','C2'):'1+1'})
            with self.assertRaises(ValueError):
                for _, rows in read_workbook(p,'modicidade_tarifaria','202610'): list(rows)

    def test_discount_auxiliary_header_total_is_not_a_table_column(self):
        with tempfile.TemporaryDirectory() as d:
            p=make_xlsx(Path(d)/'desconto_tarifario_202610.xlsx',{'EQTL_MA':[
                ['EMPRESA','MES_COMPETENCIA','RECEITA',None,None,15],
                ['EQTL_MA','202610',15]]},formulas={('EQTL_MA','F1'):'SUM(C2:C2)'})
            for info, rows in read_workbook(p,'desconto_tarifario','202610'):
                self.assertEqual(info.headers,('EMPRESA','MES_COMPETENCIA','RECEITA'))
                self.assertEqual(list(rows)[0]['RECEITA'],Decimal('15'))

    def test_discount_data_in_auxiliary_header_area_is_not_silently_dropped(self):
        with tempfile.TemporaryDirectory() as d:
            p=make_xlsx(Path(d)/'desconto_tarifario_202610.xlsx',{'EQTL_MA':[
                ['EMPRESA','MES_COMPETENCIA','RECEITA',None,None,15],
                ['EQTL_MA','202610',15,None,None,'dado inesperado']]},
                formulas={('EQTL_MA','F1'):'SUM(C2:C2)'})
            with self.assertRaisesRegex(ValueError,'fora da tabela'):
                for _, rows in read_workbook(p,'desconto_tarifario','202610'): list(rows)


if __name__=='__main__':unittest.main()
