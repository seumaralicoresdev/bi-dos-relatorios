-- CANDIDATO: revisão estática de colunas, sem execução no Snowflake.
-- Validar unicidade dos joins e reconciliar totais antes de substituir a consulta.
-- Intervalo inclusivo MES_INICIO..MES_FIM, uma chamada por empresa.
-- Não executar novamente por cada mês do mesmo intervalo.
-- RASCUNHO: agrega itens antes do join; não injeta linha fictícia.
-- FATURAMENTO precisa ser único na chave completa abaixo. MWh segue a divisão por 1000 do SQL de automação.
WITH ITENS AS (
 SELECT MES_COMPETENCIA, DOCUMENTO_IMPRESSAO, DOCUMENTO_CALCULO, SUM(RECEITA) AS RECEITA
 FROM EQTLINFO_PRD.{SCHEMA}.ITENS_FATURAMENTO
 WHERE ITEM_DOCUMENTO='ZESCAS'
   AND MES_COMPETENCIA BETWEEN '{MES_INICIO}' AND '{MES_FIM}'
 GROUP BY MES_COMPETENCIA, DOCUMENTO_IMPRESSAO, DOCUMENTO_CALCULO
)
SELECT '{EMP}' AS "EmpresaChave", TO_DATE(I.MES_COMPETENCIA||'01','YYYYMMDD') AS "DataCompetencia",
       TO_VARCHAR(I.DOCUMENTO_IMPRESSAO) AS "DocumentoImpressao",
       TO_VARCHAR(I.DOCUMENTO_CALCULO) AS "DocumentoCalculo",
       TO_VARCHAR(B.INSTALACAO) AS "Instalacao", B.ESTORNADO AS "EstornadoOrigem",
       I.RECEITA AS "ValorEncargoAssinado", B.CONSUMO_FATURADO AS "ConsumoFaturaOrigem",
       TO_VARCHAR(B.MES_REFERENCIA) AS "MesReferencia",
       TRY_TO_DATE(TO_VARCHAR(B.MES_REFERENCIA)||'01','YYYYMMDD') AS "DataReferencia",
       B.CONSUMO_FATURADO / 1000 AS "MWh",
       B.DATA_DADOS AS "DataDados"
FROM ITENS I LEFT JOIN EQTLINFO_PRD.{SCHEMA}.FATURAMENTO B
 ON I.MES_COMPETENCIA=B.MES_COMPETENCIA AND I.DOCUMENTO_IMPRESSAO=B.DOCUMENTO_IMPRESSAO
 AND I.DOCUMENTO_CALCULO=B.DOCUMENTO_CALCULO;
