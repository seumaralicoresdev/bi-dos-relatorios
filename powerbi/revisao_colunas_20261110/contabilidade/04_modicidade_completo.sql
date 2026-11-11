-- CANDIDATO DE REVISAO: nao executado no Snowflake e nao publicado.
-- Relatorio: modicidade tarifaria; tabela proposta: FatoModicidade.
-- Fonte: 5447_SQL_TEMPLATE.sql; SHA256 6467376891ae818f597c82449e0b40c375d09b4560f05ba0498d0fc35f0ca4b3.
-- Modo de carga: mensal_referencia. Consulte audit.json antes de usar.
-- IDs convertidos a texto, sem conversao numerica; meses como primeiro dia do mes.
-- Nao aplicar DISTINCT/ABS; regra e grao internos preservados salvo ajustes listados.
WITH ORIGEM AS (
-- ===========================================
-- BLOCO MODIC TARIFÁRIA
-- ===========================================
SELECT
    '{EMP}' AS EMPRESA, REFERENCIA, MES_LANCAMENTO, CATEGORIA_DOC_SUBSTITUTO,
    STATUS_DOC_SUBST, OPERACAO, SUB_OPERACAO, DESCRICAO, ITEM_ESTATISTICO, max(CLASSE) AS classe,
    CONTA_CONTRATO, NUMERO_DOCUMENTO, BLOQUEIO, VALOR
FROM SB_FATURAMENTO.{SCHEMA}.BASE_MODIC_TAR_NOVO
WHERE REFERENCIA = '{MES}'
GROUP BY ALL
)
SELECT
    TO_VARCHAR(EMPRESA) AS "EmpresaChave",
    TRY_TO_DATE(TO_VARCHAR(REFERENCIA) || '01', 'YYYYMMDD') AS "DataCompetencia",
    TO_VARCHAR(MES_LANCAMENTO) AS "MesLancamento",
    TO_VARCHAR(CATEGORIA_DOC_SUBSTITUTO) AS "CategoriaDocSubstituto",
    TO_VARCHAR(STATUS_DOC_SUBST) AS "StatusDocSubst",
    TO_VARCHAR(OPERACAO) AS "Operacao",
    TO_VARCHAR(SUB_OPERACAO) AS "SubOperacao",
    TO_VARCHAR(DESCRICAO) AS "Descricao",
    TO_VARCHAR(ITEM_ESTATISTICO) AS "ItemEstatistico",
    TO_VARCHAR(CLASSE) AS "ClasseOrigem",
    TO_VARCHAR(CONTA_CONTRATO) AS "ContaContrato",
    TO_VARCHAR(NUMERO_DOCUMENTO) AS "NumeroDocumento",
    TO_VARCHAR(BLOQUEIO) AS "Bloqueio",
    VALOR AS "ValorModicidadeAssinado"
FROM ORIGEM
