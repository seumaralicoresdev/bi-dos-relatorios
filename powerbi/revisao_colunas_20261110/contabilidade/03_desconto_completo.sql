-- CANDIDATO DE REVISAO: nao executado no Snowflake e nao publicado.
-- Relatorio: desconto tarifario; tabela proposta: FatoDesconto.
-- Fonte: 4451_SQL_TEMPLATE.sql; SHA256 e339f9111dc55d49755389881a9b45f5450ced1fd59e62ae0d44bd173e03dec4.
-- Modo de carga: mensal_competencia. Consulte audit.json antes de usar.
-- IDs convertidos a texto, sem conversao numerica; meses como primeiro dia do mes.
-- Nao aplicar DISTINCT/ABS; regra e grao internos preservados salvo ajustes listados.
WITH ORIGEM AS (
SELECT EMPRESA, MES_COMPETENCIA, ITEM_ORDENACAO, ITEM_DOCUMENTO, SUB_OPERACAO, CHAVE_RECONCILIACAO,
  INSTALACAO, CONTA_CONTRATO, CONTRATO, FATURA, CATEGORIA_TARIFA, SUBCLASSE,
  SUM(RECEITA) AS RECEITA,
  DOCUMENTO_IMPRESSAO, CASE WHEN ITEM_ORDENACAO <> 'ZBTL' THEN 'X' END AS GD,
  FROM
      (
        SELECT '{EMP}' AS EMPRESA,
                a.mes_competencia,
                item_ordenacao,
                CASE WHEN item_documento = 'SUBT' THEN ITEM_ORDENACAO ELSE ITEM_DOCUMENTO END AS ITEM_DOCUMENTO,
                MAX(MAX(a.sub_operacao)) OVER (PARTITION BY B.DOCUMENTO_IMPRESSAO, A.ITEM_ORDENACAO) AS sub_operacao,
                b.chave_reconciliacao,
                b.instalacao,
                b.conta_contrato,
                b.contrato,
                b.fatura,
                B.categoria_tarifa,
                B.subclasse,
                a.RECEITA,
                b.documento_impressao,
                a.linha,
        FROM EQTLINFO_PRD.{SCHEMA}.ITENS_FATURAMENTO A
        INNER JOIN EQTLINFO_PRD.{SCHEMA}.FATURAMENTO b ON a.documento_impressao = b.documento_impressao and a.documento_calculo = b.documento_calculo
        WHERE 1=1
        and A.mes_competencia = '{MES}'
        --AND CHAVE_RECONCILIACAO = 'R260429000R4'
        and (A.ITEM_ORDENACAO in ('YBTL','Z02L','Z03L','Z12L','Z13L','Z22L','Z23L','Z32L','Z33L','Z42L','Z43L','Z52L','Z53L','Z62L','Z63L','Z72L','Z73L','Z82L','Z83L',
            'Z92L','Z93L','ZBCL','ZBGL','ZBLP','ZBLS','ZBSL','ZBTL') OR A.ITEM_ORDENACAO LIKE 'ZL%')
        AND ITEM_DOCUMENTO <> 'ZBTLBR'
        GROUP BY all
     )
 WHERE RECEITA <> 0
   AND SUB_OPERACAO NOT IN ('0053', '0063')
 GROUP BY ALL
 HAVING SUM(RECEITA) <> 0
)
SELECT
    TO_VARCHAR(EMPRESA) AS "EmpresaChave",
    TRY_TO_DATE(TO_VARCHAR(MES_COMPETENCIA) || '01', 'YYYYMMDD') AS "DataCompetencia",
    TO_VARCHAR(ITEM_ORDENACAO) AS "ItemOrdenacao",
    TO_VARCHAR(ITEM_DOCUMENTO) AS "ItemDocumento",
    TO_VARCHAR(SUB_OPERACAO) AS "SubOperacao",
    TO_VARCHAR(CHAVE_RECONCILIACAO) AS "ChaveReconciliacao",
    TO_VARCHAR(INSTALACAO) AS "Instalacao",
    TO_VARCHAR(CONTA_CONTRATO) AS "ContaContrato",
    TO_VARCHAR(CONTRATO) AS "Contrato",
    TO_VARCHAR(FATURA) AS "Fatura",
    TO_VARCHAR(CATEGORIA_TARIFA) AS "CategoriaTarifa",
    TO_VARCHAR(SUBCLASSE) AS "Subclasse",
    RECEITA AS "ValorDescontoAssinado",
    TO_VARCHAR(DOCUMENTO_IMPRESSAO) AS "DocumentoImpressao",
    TO_VARCHAR(GD) AS "MarcadorGDOrigem"
FROM ORIGEM
