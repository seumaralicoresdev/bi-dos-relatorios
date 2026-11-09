"""Executa o SQL do piloto em SQLite com funções de conversão equivalentes.

Valida a lógica relacional em dados sintéticos. Não substitui execução no
Snowflake, validação do conector M nem medição de desempenho do warehouse.
"""
from datetime import datetime
from pathlib import Path
import sqlite3
import unittest


SQL_FILE = Path(__file__).resolve().parents[1] / 'powerbi/otimizacao/02_fato_desconto_resumo.sql'


class DescontoResumoSQLTests(unittest.TestCase):
    def run_query(self, items, start='202610', end='202610'):
        self.assertTrue(SQL_FILE.is_file(), 'Consulta resumida ainda não implementada')
        sql = SQL_FILE.read_text(encoding='utf-8')
        # Somente qualificação do catálogo e parâmetros são adaptados.
        sql = sql.replace('EQTLINFO_PRD.{SCHEMA}.', '')
        for token, value in {'{EMP}': 'EQTL_MA', '{MES_INICIO}': start, '{MES_FIM}': end}.items():
            sql = sql.replace(token, value)

        def try_date(value, mask):
            if value is None:
                return None
            try:
                return datetime.strptime(str(value), '%Y%m%d').date().isoformat()
            except ValueError:
                return None

        with sqlite3.connect(':memory:') as db:
            db.row_factory = sqlite3.Row
            db.execute('PRAGMA case_sensitive_like=ON')
            db.create_function('TO_VARCHAR', 1, lambda value: None if value is None else str(value))
            db.create_function('TRY_TO_DATE', 2, try_date)
            db.executescript('''
                CREATE TABLE ITENS_FATURAMENTO (
                    MES_COMPETENCIA TEXT, DOCUMENTO_IMPRESSAO TEXT, DOCUMENTO_CALCULO TEXT,
                    ITEM_ORDENACAO TEXT, ITEM_DOCUMENTO TEXT, SUB_OPERACAO TEXT,
                    RECEITA NUMERIC, LINHA TEXT
                );
                CREATE TABLE FATURAMENTO (
                    DOCUMENTO_IMPRESSAO TEXT, DOCUMENTO_CALCULO TEXT,
                    CHAVE_RECONCILIACAO TEXT, INSTALACAO TEXT, CONTA_CONTRATO TEXT,
                    CONTRATO TEXT, FATURA TEXT, CATEGORIA_TARIFA TEXT, SUBCLASSE TEXT,
                    PRIMARY KEY(DOCUMENTO_IMPRESSAO, DOCUMENTO_CALCULO)
                );
            ''')
            for item in items:
                month, document, value = item[:3]
                extra = item[3] if len(item) > 3 else {}
                db.execute('INSERT INTO ITENS_FATURAMENTO VALUES (?,?,?,?,?,?,?,?)', (
                    month, document, 'CALC', extra.get('item', 'YBTL'),
                    extra.get('document_item', 'ITEM'), extra.get('operation', '0070'),
                    value, extra.get('line', '1')
                ))
                db.execute('INSERT OR IGNORE INTO FATURAMENTO VALUES (?,?,?,?,?,?,?,?,?)', (
                    document, 'CALC', 'CHAVE', 'INST_' + document, 'CONTA_' + document,
                    'CONTRATO_' + document, 'FATURA_' + document,
                    extra.get('category', 'B1'), extra.get('subclass', 'RE')
                ))
            return [dict(row) for row in db.execute(sql)]

    def test_combines_documents_into_category_totals_without_individual_ids(self):
        result = self.run_query([('202610', 'D1', 100), ('202610', 'D2', 20), ('202610', 'D3', -5)])
        self.assertEqual(result, [{
            'EmpresaChave': 'EQTL_MA', 'DataCompetencia': '2026-10-01',
            'ItemOrdenacao': 'YBTL', 'ItemDocumento': 'ITEM', 'SubOperacao': '0070',
            'MarcadorGDOrigem': 'X', 'CategoriaTarifa': 'B1', 'Subclasse': 'RE',
            'ValorDescontoAssinado': 115, 'LinhasOrigem': 3
        }])

    def test_period_crosses_year_and_excludes_invalid_and_outside_months(self):
        result = self.run_query([
            ('202601', 'D1', 10), ('202701', 'D2', 20),
            ('202512', 'D3', 999), ('202702', 'D4', 999), ('202613', 'D5', 999)
        ], '202601', '202701')
        self.assertEqual(sorted((r['DataCompetencia'], r['ValorDescontoAssinado']) for r in result),
                         [('2026-01-01', 10), ('2027-01-01', 20)])

    def test_window_does_not_mix_operation_of_same_document_across_months(self):
        result = self.run_query([
            ('202610', 'D1', 10, {'operation': '0053'}),
            ('202611', 'D1', 20, {'operation': '0070'})
        ], '202610', '202611')
        self.assertEqual([(r['DataCompetencia'], r['ValorDescontoAssinado']) for r in result],
                         [('2026-11-01', 20)])

    def test_keeps_observed_zero_but_excludes_cancelled_source_group(self):
        result = self.run_query([
            ('202610', 'D1', 10), ('202610', 'D2', -10),
            ('202610', 'D3', 20, {'line': '1'}), ('202610', 'D3', -20, {'line': '2'})
        ])
        self.assertEqual(len(result), 1)
        self.assertEqual((result[0]['ValorDescontoAssinado'], result[0]['LinhasOrigem']), (0, 2))

    def test_preserves_legacy_grouping_of_identical_join_rows(self):
        result = self.run_query([('202610', 'D1', 10), ('202610', 'D1', 10)])
        self.assertEqual((result[0]['ValorDescontoAssinado'], result[0]['LinhasOrigem']), (10, 1))

    def test_preserves_subt_mapping_null_categories_and_gd_marker(self):
        result = self.run_query([('202610', 'D1', 10, {
            'item': 'ZBTL', 'document_item': 'SUBT', 'category': None, 'subclass': None
        })])
        self.assertEqual((result[0]['ItemDocumento'], result[0]['MarcadorGDOrigem'],
                          result[0]['CategoriaTarifa'], result[0]['Subclasse']),
                         ('ZBTL', None, None, None))

    def test_preserves_item_exclusions_and_signed_amounts(self):
        result = self.run_query([
            ('202610', 'D1', -5), ('202610', 'D2', 100, {'item': 'OUTRO'}),
            ('202610', 'D3', 100, {'document_item': 'ZBTLBR'}),
            ('202610', 'D4', 100, {'operation': '0063'}),
            ('202610', 'D5', 100, {'operation': None})
        ])
        self.assertEqual((result[0]['ValorDescontoAssinado'], result[0]['LinhasOrigem']), (-5, 1))


if __name__ == '__main__':
    unittest.main()
