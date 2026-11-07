"""Export only catalog-approved aggregates from private Parquet partitions.

The caller supplies metric and dimension allowlists after validating source and
partition metadata. Private source columns are never materialized here unless
they are explicitly part of those allowlists.
"""

from collections.abc import Sequence
from dataclasses import dataclass
from decimal import Decimal, localcontext
from pathlib import Path

import pyarrow.parquet as pq


@dataclass
class _MetricTotal:
    value: Decimal = Decimal(0)
    observed_rows: int = 0

    def add(self, value: Decimal) -> None:
        # Decimal's default 28-digit context can round valid decimal128 inputs.
        # Allow every source decimal place plus one digit for a possible carry.
        precision = (
            max(self.value.adjusted(), value.adjusted())
            - min(self.value.as_tuple().exponent, value.as_tuple().exponent)
            + 2
        )
        with localcontext() as context:
            context.prec = max(context.prec, precision)
            self.value += value
        self.observed_rows += 1

    def export(self) -> dict:
        return {
            "value": format(self.value, "f") if self.observed_rows else None,
            "observed_rows": self.observed_rows,
        }


def _metric_value(value, field: str) -> Decimal | None:
    if value is None:
        return None
    if isinstance(value, bool) or not isinstance(value, (int, float, Decimal)):
        raise ValueError(f"Métrica '{field}' contém observação não numérica")
    decimal = Decimal(str(value))
    if not decimal.is_finite():
        raise ValueError(f"Métrica '{field}' contém observação não finita")
    return decimal


def summarize_partition(
    paths: list[Path],
    *,
    report_id: str,
    company: str,
    delivery_month: str,
    metrics: Sequence[str],
    dimensions: Sequence[str],
) -> dict:
    """Summarize a validated partition in bounded Arrow record batches.

    Missing metric observations remain unavailable, while observed zero keeps
    its numeric meaning. Each dimension has its own complete breakdown; null
    dimension values remain JSON null and do not collide with literal labels.
    """
    metric_names = tuple(dict.fromkeys(metrics))
    dimension_names = tuple(dict.fromkeys(dimensions))
    projected_names = tuple(dict.fromkeys((*metric_names, *dimension_names)))
    totals = {name: _MetricTotal() for name in metric_names}
    groups: dict[str, dict[str | None, dict]] = {
        name: {} for name in dimension_names
    }
    rows = 0

    for path in paths:
        parquet = pq.ParquetFile(path)
        available_names = set(parquet.schema_arrow.names)
        projected = [name for name in projected_names if name in available_names]
        for batch in parquet.iter_batches(batch_size=65536, columns=projected):
            columns = batch.to_pydict()
            rows += batch.num_rows
            for index in range(batch.num_rows):
                observations = {
                    name: _metric_value(columns[name][index], name)
                    if name in columns else None
                    for name in metric_names
                }
                for name, value in observations.items():
                    if value is not None:
                        totals[name].add(value)

                for dimension in dimension_names:
                    raw_key = columns[dimension][index] if dimension in columns else None
                    key = None if raw_key is None else str(raw_key)
                    group = groups[dimension].get(key)
                    if group is None:
                        group = {
                            "rows": 0,
                            "metrics": {name: _MetricTotal() for name in metric_names},
                        }
                        groups[dimension][key] = group
                    group["rows"] += 1
                    for name, value in observations.items():
                        if value is not None:
                            group["metrics"][name].add(value)

    return {
        "report_id": report_id,
        "company": company,
        "delivery_month": delivery_month,
        "rows": rows,
        "metrics": {name: total.export() for name, total in totals.items()},
        "breakdowns": {
            dimension: [
                {
                    "key": key,
                    "rows": group["rows"],
                    "metrics": {
                        name: total.export() for name, total in group["metrics"].items()
                    },
                }
                for key, group in sorted(
                    dimension_groups.items(), key=lambda item: (item[0] is not None, item[0] or "")
                )
            ]
            for dimension, dimension_groups in groups.items()
        },
    }
