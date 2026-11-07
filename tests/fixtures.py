"""Workbooks sintéticos mínimos usados apenas pelos testes do leitor."""
from pathlib import Path
from xml.sax.saxutils import escape, quoteattr
from decimal import Decimal
import zipfile


def make_xlsx(path: Path, sheets: dict[str, list[list]], *, formulas=None):
    formulas = formulas or {}
    def column(index):
        out = ''
        while index:
            index, rest = divmod(index - 1, 26)
            out = chr(65 + rest) + out
        return out
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
        names = list(sheets)
        z.writestr('xl/workbook.xml',
            '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
            'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>' +
            ''.join(f'<sheet name={quoteattr(name)} sheetId="{i}" r:id="rId{i}"/>' for i, name in enumerate(names, 1)) +
            '</sheets></workbook>')
        z.writestr('xl/_rels/workbook.xml.rels',
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
            ''.join(f'<Relationship Id="rId{i}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet{i}.xml"/>' for i in range(1, len(names)+1)) +
            '</Relationships>')
        for i, (name, rows) in enumerate(sheets.items(), 1):
            lines = []
            for r, values in enumerate(rows, 1):
                cells = []
                for c, value in enumerate(values, 1):
                    address = column(c) + str(r)
                    if (name, address) in formulas:
                        cached = '' if value is None else f'<v>{escape(str(value))}</v>'
                        cells.append(f'<c r="{address}"><f>{escape(formulas[name, address])}</f>{cached}</c>')
                    elif value is None:
                        continue
                    elif isinstance(value, (int, float, Decimal)):
                        cells.append(f'<c r="{address}"><v>{value}</v></c>')
                    else:
                        cells.append(f'<c r="{address}" t="inlineStr"><is><t>{escape(str(value))}</t></is></c>')
                lines.append(f'<row r="{r}">' + ''.join(cells) + '</row>')
            z.writestr(f'xl/worksheets/sheet{i}.xml',
                '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>' +
                ''.join(lines) + '</sheetData></worksheet>')
    return path


def modicidade(path: Path, rows=None, company='EQTL_MA', month='202610', sheet=None):
    return make_xlsx(path, {sheet or company: [
        ['EMPRESA', 'REFERENCIA', 'VALOR', 'CONTA_CONTRATO', 'OPERACAO'],
        *([[company, month, 10, '0000123', '0153']] if rows is None else rows)
    ]})
