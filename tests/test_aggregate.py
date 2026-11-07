"""Synthetic Parquet checks for the private aggregate export boundary."""

from decimal import Decimal
import json
from pathlib import Path
import tempfile
import unittest

import pyarrow as pa
import pyarrow.parquet as pq

from base_comum.aggregate import summarize_partition


class AggregateTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)

    def write_parquet(self, name, columns, schema=None):
        path = self.root / name
        pq.write_table(pa.table(columns, schema=schema), path)
        return path

    def summarize(self, paths, *, metrics=("valor",), dimensions=()):
        return summarize_partition(
            paths,
            report_id="relatorio_sintetico",
            company="EMPRESA_TESTE",
            delivery_month="202701",
            metrics=metrics,
            dimensions=dimensions,
        )

    def test_sums_float_and_decimal_files_preserving_negative_values(self):
        first = self.write_parquet("first.parquet", {"valor": [0.1, -0.2]})
        second = self.write_parquet(
            "second.parquet", {"valor": [Decimal("0.30")]}
        )

        result = self.summarize([first, second])

        self.assertEqual(result["report_id"], "relatorio_sintetico")
        self.assertEqual(result["company"], "EMPRESA_TESTE")
        self.assertEqual(result["delivery_month"], "202701")
        self.assertEqual(result["rows"], 3)
        self.assertIsInstance(result["metrics"]["valor"]["value"], str)
        self.assertEqual(Decimal(result["metrics"]["valor"]["value"]), Decimal("0.20"))
        self.assertEqual(result["metrics"]["valor"]["observed_rows"], 3)
        self.assertEqual(result["breakdowns"], {})

    def test_null_and_missing_metrics_remain_unavailable_but_observed_zero_is_zero(self):
        path = self.write_parquet(
            "nulls.parquet", {"valor": [None, None], "zero": [0.0, None]}
        )

        result = self.summarize([path], metrics=("valor", "zero", "ausente"))

        self.assertEqual(result["rows"], 2)
        self.assertEqual(result["metrics"]["valor"], {"value": None, "observed_rows": 0})
        self.assertEqual(result["metrics"]["ausente"], {"value": None, "observed_rows": 0})
        self.assertEqual(Decimal(result["metrics"]["zero"]["value"]), Decimal("0"))
        self.assertEqual(result["metrics"]["zero"]["observed_rows"], 1)

    def test_empty_partition_has_no_observations(self):
        result = self.summarize([], dimensions=("categoria",))

        self.assertEqual(result["rows"], 0)
        self.assertEqual(result["metrics"], {"valor": {"value": None, "observed_rows": 0}})
        self.assertEqual(result["breakdowns"], {"categoria": []})

    def test_breakdowns_reconcile_and_keep_null_separate_from_literal_category(self):
        path = self.write_parquet(
            "groups.parquet",
            {
                "valor": [10.0, -3.0, None, 0.0, 2.0],
                "categoria": ["A", "A", "B", None, "(sem valor)"],
            },
        )

        result = self.summarize([path], dimensions=("categoria",))

        groups = {entry["key"]: entry for entry in result["breakdowns"]["categoria"]}
        self.assertEqual(set(groups), {"A", "B", None, "(sem valor)"})
        self.assertEqual(groups["A"], {
            "key": "A", "rows": 2,
            "metrics": {"valor": {"value": "7.0", "observed_rows": 2}},
        })
        self.assertEqual(groups["B"]["metrics"]["valor"], {"value": None, "observed_rows": 0})
        self.assertEqual(groups[None]["metrics"]["valor"]["observed_rows"], 1)
        self.assertEqual(sum(group["rows"] for group in groups.values()), 5)
        self.assertEqual(
            sum(Decimal(group["metrics"]["valor"]["value"])
                for group in groups.values()
                if group["metrics"]["valor"]["value"] is not None),
            Decimal(result["metrics"]["valor"]["value"]),
        )
        self.assertEqual(
            sum(group["metrics"]["valor"]["observed_rows"] for group in groups.values()),
            result["metrics"]["valor"]["observed_rows"],
        )

    def test_only_requested_metrics_and_dimensions_cross_export_boundary(self):
        path = self.write_parquet(
            "private.parquet",
            {
                "valor": [2.0, 4.0],
                "categoria": ["A", "A"],
                "cpf": ["00123456789", "00987654321"],
                "nome": ["Pessoa Sintetica Um", "Pessoa Sintetica Dois"],
                "endereco": ["Rua Sintetica 123", "Rua Sintetica 456"],
                "instalacao": ["000001", "000002"],
                "__empresa": ["EMPRESA_TESTE", "EMPRESA_TESTE"],
                "__competencia_remessa": ["202701", "202701"],
                "__periodo_dados": ["202612", "202612"],
                "__source_file": ["arquivo_privado.xlsx", "arquivo_privado.xlsx"],
                "__source_sheet": ["aba_privada", "aba_privada"],
                "__source_row": [2, 3],
            },
        )

        result = self.summarize([path], dimensions=("categoria",))

        self.assertEqual(set(result), {
            "report_id", "company", "delivery_month", "rows", "metrics", "breakdowns"
        })
        self.assertEqual(set(result["metrics"]), {"valor"})
        self.assertEqual(set(result["breakdowns"]), {"categoria"})
        serialized = json.dumps(result, ensure_ascii=False)
        for private_text in (
            "cpf", "nome", "endereco", "instalacao", "00123456789",
            "Pessoa Sintetica", "Rua Sintetica", "__source", "arquivo_privado",
            "aba_privada", "__periodo_dados", "202612",
        ):
            with self.subTest(private_text=private_text):
                self.assertNotIn(private_text, serialized)

    def test_rejects_non_numeric_and_non_finite_metric_observations(self):
        for index, invalid_value in enumerate(("invalido", float("nan"), float("inf"), -float("inf"))):
            with self.subTest(invalid_value=invalid_value):
                path = self.write_parquet(f"invalid-{index}.parquet", {"valor": [invalid_value]})
                with self.assertRaisesRegex(ValueError, "valor"):
                    self.summarize([path])

    def test_decimal_sum_does_not_round_high_precision_source_values(self):
        path = self.write_parquet(
            "precise.parquet",
            {"valor": [Decimal("123456789012345678901234567890.12"), Decimal("0.01")]},
            schema=pa.schema([("valor", pa.decimal128(36, 2))]),
        )

        result = self.summarize([path])

        self.assertEqual(result["metrics"]["valor"]["value"], "123456789012345678901234567890.13")

    def test_counts_rows_with_no_projected_columns_across_record_batches(self):
        path = self.write_parquet("many.parquet", {"cpf": ["00000000000"] * 65537})

        result = self.summarize([path], metrics=(), dimensions=())

        self.assertEqual(result["rows"], 65537)
        self.assertEqual(result["metrics"], {})
        self.assertEqual(result["breakdowns"], {})


if __name__ == "__main__":
    unittest.main()
