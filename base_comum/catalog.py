"""Contratos das famílias, sem dados das planilhas."""
from dataclasses import dataclass
import re
import unicodedata

COMPANIES = ('EQTL_MA','EQTL_PA','EQTL_PI','EQTL_AL','EQTL_AP','EQTL_RS')


@dataclass(frozen=True)
class ReportSpec:
    id: str
    domain: str
    period_column: str | None
    metrics: tuple[str,...] = ()
    dimensions: tuple[str,...] = ()
    quantities: tuple[str,...] = ()

    @property
    def number_fields(self):
        return set(self.metrics) | set(self.quantities)

    @property
    def required(self):
        return set(self.metrics) | ({self.period_column} if self.period_column else set())


def _r(id, domain, period, metrics=(), dimensions=(), quantities=()):
    return ReportSpec(id,domain,period,tuple(metrics),tuple(dimensions),tuple(quantities))


REPORTS = {r.id:r for r in (
    _r('clientes_cativos','contabilidade','MES_COMPETENCIA',
       ('VALOR_FATURADO','MONTANTE_ICMS','MONTANTE_PIS','MONTANTE_COFINS','VALOR_SEM_IMPOSTO'),
       ('CLASSE_PRINCIPAL','GRUPO','COD_CATEGORIA_TARIFA','ITEM_DOCUMENTO')),
    _r('clientes_livres','contabilidade','MES_COMPETENCIA',
       ('VALOR_FATURADO','MONTANTE_ICMS','MONTANTE_PIS','MONTANTE_COFINS','VALOR_SEM_IMPOSTO'),
       ('CLASSE','GRUPO','COD_CATEGORIA_TARIFA','ITEM_DOCUMENTO')),
    _r('desconto_tarifario','contabilidade','MES_COMPETENCIA',('RECEITA',),('ITEM_ORDENACAO','SUB_OPERACAO','GD')),
    _r('mmgd','contabilidade','MES',('KWH',),('MES',)),
    _r('reativos_excedentes','contabilidade','MES_COMPETENCIA',('VALOR_FATURADO','VALOR_SEM_IMPOSTO'),('CLASSE','ITEM_DOCUMENTO')),
    _r('resumo_faturamento','contabilidade','MES_COMPETENCIA',('ICMS','PIS','COFINS','SUBVENCAO_BXRENDA'),('CLASSE','CLIENTE_LIVRE')),
    _r('saldo_bloqueado','contabilidade','REFERENCIA',('QUANTIDADE',),('MES_ORIGEM_CREDITO',)),
    _r('tusd_geradores','contabilidade','MES_COMPETENCIA',
       ('VALOR_FATURADO','MONTANTE_ICMS','MONTANTE_PIS','MONTANTE_COFINS','VALOR_SEM_IMPOSTO'),('CLASSE','ITEM_DOCUMENTO')),
    _r('ultrapassagem_demanda','contabilidade','MES_COMPETENCIA',('VALOR_FATURADO','VALOR_SEM_IMPOSTO'),('CLASSE','ITEM_DOCUMENTO')),
    _r('modicidade_tarifaria','contabilidade','REFERENCIA',('VALOR',),('OPERACAO','SUB_OPERACAO','BLOQUEIO','STATUS_DOC_SUBST')),
    _r('consumo_proprio','tributario','COMPETENCIA',('VALOR_TOTAL','ICMS_TOTAL','BC_ICMS'),('REGIONAL','MUNICIPIO','TIPO_SISTEMA','SITUACAO_DOCUMENTO')),
    _r('encargo_covid','tributario','MES_COMPETENCIA',('RECEITA',),('ESTORNADO',)),
    _r('encargo_escassez_hidrica','tributario','MES_COMPETENCIA',('RECEITA',),('ESTORNADO',)),
    # Cabeçalhos/notas podem repetir. Nenhum total monetário automático nesta fase.
    _r('financiamento_padrao','tributario',None,(),('MOEDA','STATUS_FINANCIAMENTO_FAT')),
    _r('isencao_icms_tusd','tributario','MES_COMPETENCIA',('REDUCAO',),('MUNICIPIO','GRUPO','CLASSE')),
    _r('retencao_tributos','tributario','MES_COMPETENCIA',
       ('VALORES_RETIDOS_PIS','VALORES_RETIDOS_COFINS','VALORES_RETIDOS_IR','VALORES_RETIDOS_CSLL')),
    # RECEITA é valor dos itens; não é uma coluna de ICMS.
    _r('icms_injetada','tributario','MES_COMPETENCIA',('RECEITA',)),
)}


def normalize_header(value):
    value=unicodedata.normalize('NFKD',str(value or '')).encode('ascii','ignore').decode().upper().strip()
    return re.sub(r'[^A-Z0-9_]+','_',value).strip('_')


def get_spec(report_id):
    try:return REPORTS[report_id]
    except KeyError:raise ValueError(f'Relatório desconhecido: {report_id}') from None


def infer_report(filename):
    name=normalize_header(filename)
    rules=(('CLIENTES_CATIVOS','clientes_cativos'),('CLIENTES_LIVRES','clientes_livres'),
           ('DESCONTO_TARIFARIO','desconto_tarifario'),('MMGD','mmgd'),
           ('REATIVOS','reativos_excedentes'),('RESUMO_FAT','resumo_faturamento'),
           ('SALDO_BLOQUEADO','saldo_bloqueado'),('TUSD_GERADORES','tusd_geradores'),
           ('ULTRAPASSAGEM','ultrapassagem_demanda'),('MODICIDADE','modicidade_tarifaria'),
           ('EQTL_PA_MODICIDAD','modicidade_tarifaria'),('CONSUMO_PROPRIO','consumo_proprio'),
           ('ENCARGO_COVID','encargo_covid'),('ESCASSEZ_HIDRICA','encargo_escassez_hidrica'),
           ('FINANC_PADRAO','financiamento_padrao'),('FINANCIAMENTO_PADRAO','financiamento_padrao'),
           ('ISENCAO_ICMS_TUSD','isencao_icms_tusd'),('RETENCAO_TRIBUTOS','retencao_tributos'),
           ('ICMS_INJET','icms_injetada'))
    for prefix,report_id in rules:
        if name.startswith(prefix):return report_id
    raise ValueError(f'Nome de arquivo sem relatório reconhecido: {filename}')


def validate_month(value):
    value=str(value).strip()
    if not re.fullmatch(r'[0-9]{6}',value) or not 1<=int(value[4:])<=12 or int(value[:4])<1:
        raise ValueError('Competência deve ser YYYYMM com mês válido.')
    return value


def infer_delivery_month(path):
    matches={m for m in re.findall(r'(?<!\d)(\d{6})(?!\d)',str(path)) if 1<=int(m[4:])<=12}
    if len(matches)!=1:raise ValueError('Informe a competência da remessa explicitamente para este arquivo.')
    return validate_month(matches.pop())
