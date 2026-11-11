-- CANDIDATO DE REVISAO: nao executado no Snowflake e nao publicado.
-- Relatorio: mmgd; tabela proposta: FatoMMGDConsolidado.
-- Fonte: 5191_SQL_TEMPLATE.sql; SHA256 0b9fe1449bc2b5d3ca60205d49b0efb1cbe89ac029256c95a7fea87cc82c9e0c.
-- Modo de carga: intervalo_3_meses_uma_chamada. Consulte audit.json antes de usar.
-- IDs convertidos a texto, sem conversao numerica; meses como primeiro dia do mes.
-- Nao aplicar DISTINCT/ABS; regra e grao internos preservados salvo ajustes listados.
-- Janela alterada explicitamente de 61 para 3 meses inclusivos; uma chamada por distribuidora.
WITH ORIGEM AS (
SELECT
    '{EMP}' AS EMPRESA,
    A.MES AS MES,
    SUM(A.KWH) AS KWH
FROM SB_FATURAMENTO.{SCHEMA}.BASE_MMGD_CREDITOS A
WHERE A.MES BETWEEN
      TO_CHAR(ADD_MONTHS(TO_DATE('{MES}' || '01', 'YYYYMMDD'), -2), 'YYYYMM')
      AND '{MES}'
GROUP BY
    A.MES
ORDER BY MES
)
SELECT
    TO_VARCHAR(EMPRESA) AS "EmpresaChave",
    TRY_TO_DATE(TO_VARCHAR(MES) || '01', 'YYYYMMDD') AS "DataMesCredito",
    KWH AS "CreditoKWh"
FROM ORIGEM
