-- CANDIDATO DE REVISAO: nao executado no Snowflake e nao publicado.
-- Relatorio: resumo fatramento; tabela proposta: FatoResumoFaturamento.
-- Fonte: resumo_faturamento.sql; SHA256 392604f37afec39d8928d178db3a3955c45ffa9e78a6b98502eac02602370c62.
-- Modo de carga: mensal_competencia. Consulte audit.json antes de usar.
-- IDs convertidos a texto, sem conversao numerica; meses como primeiro dia do mes.
-- Nao aplicar DISTINCT/ABS; regra e grao internos preservados salvo ajustes listados.
-- SELECT A.* substituído pela projeção explícita do Excel; nomes a confirmar no schema da origem.
WITH ORIGEM AS (
SELECT '{EMP}' AS EMPRESA, A.MES_COMPETENCIA, A.CLIENTE_LIVRE, A.CLASSE,
       A.ICMS, A.PIS, A.COFINS, A.SUBVENCAO_BXRENDA, A.DATA_DADOS
FROM SB_FATURAMENTO.{SCHEMA}.RESUMO_FAT_TRIBUTOS A
WHERE A.CLASSE IS NOT NULL AND A.MES_COMPETENCIA = '{MES}'
)
SELECT
    TO_VARCHAR(EMPRESA) AS "EmpresaChave",
    TRY_TO_DATE(TO_VARCHAR(MES_COMPETENCIA) || '01', 'YYYYMMDD') AS "DataCompetencia",
    TO_VARCHAR(CLIENTE_LIVRE) AS "ClienteLivreOrigem",
    TO_VARCHAR(CLASSE) AS "ClasseOrigem",
    ICMS AS "ICMS",
    PIS AS "PIS",
    COFINS AS "COFINS",
    SUBVENCAO_BXRENDA AS "SubvencaoBaixaRenda",
    DATA_DADOS AS "DataDados"
FROM ORIGEM
