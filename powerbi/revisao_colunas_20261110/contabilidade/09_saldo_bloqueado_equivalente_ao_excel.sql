-- CANDIDATO DE REVISAO: nao executado no Snowflake e nao publicado.
-- Relatorio: saldo bloqueado; tabela proposta: FatoSaldoBloqueado.
-- Fonte: 2049_SQL_TEMPLATE.sql; SHA256 48b5a98b2670eecb3251a37755633b091bee4590f91c7923792fdb76dd1351ea.
-- Modo de carga: snapshot_mensal. Consulte audit.json antes de usar.
-- IDs convertidos a texto, sem conversao numerica; meses como primeiro dia do mes.
-- Nao aplicar DISTINCT/ABS; regra e grao internos preservados salvo ajustes listados.
-- OPCIONAL: TRUNC do Excel preservado; difere da precisao de QuantidadeOrigem do modelo atual.
WITH ORIGEM AS (
SELECT B.*, A.CONTA_CONTRATO
FROM (
    SELECT
        '{PRD_SCHEMA}' AS EMPRESA,
        '{MES_COMPET}'  AS REFERENCIA,
        A.GEN_CONTRACT  AS CONTRATO_GERACAO,
        TO_CHAR(TRUNC(SUM(A.QUANT))) AS QUANTIDADE,
        SUBSTR(RUSE_ENDDATE, 1, 6) AS MES_ORIGEM_CREDITO
    FROM EQTLINFO_RAW.{RAW_SCHEMA}.EENRGY_CR_BR A
    WHERE 1=1
      AND RUSE_ENDDATE < TO_CHAR(ADD_MONTHS(TO_DATE('{MES_COMPET}' || '01', 'YYYYMMDD'), -60), 'YYYYMMDD')
      AND A.CREATEDDATE < TO_CHAR(ADD_MONTHS(TO_DATE('{MES_COMPET}' || '06', 'YYYYMMDD'),  1), 'YYYYMMDD')
    GROUP BY ALL
) B
INNER JOIN EQTLINFO_PRD.{PRD_SCHEMA}.TAB_CONTRATO A
    ON A.CONTRATO = B.CONTRATO_GERACAO
WHERE QUANTIDADE <> 0
)
SELECT
    TO_VARCHAR(EMPRESA) AS "EmpresaChave",
    TRY_TO_DATE(TO_VARCHAR(REFERENCIA) || '01', 'YYYYMMDD') AS "DataCompetencia",
    TO_VARCHAR(CONTRATO_GERACAO) AS "ContratoGeracao",
    TO_NUMBER(QUANTIDADE) AS "QuantidadeOrigem",
    TRY_TO_DATE(TO_VARCHAR(MES_ORIGEM_CREDITO) || '01', 'YYYYMMDD') AS "DataMesOrigemCredito",
    TO_VARCHAR(CONTA_CONTRATO) AS "ContaContrato"
FROM ORIGEM
