-- CANDIDATO: revisão estática de colunas, sem execução no Snowflake.
-- Validar unicidade dos joins e reconciliar totais antes de substituir a consulta.
-- RASCUNHO: o join DOC x SUB pode duplicar parcelas; exige chave de ambas as fontes.
WITH ORIGEM AS (
SELECT
    '{EMP}' AS EMPRESA,
    doc.NOTA,
    doc.MANDANTE,
    doc.INSTALACAO,
    doc.CONTA_CONTRATO,
    doc.PARCEIRO_NEGOCIO,
    doc.PEP_ODS,
    doc.TIPO,
    doc.DATA_CADASTRO,
    doc.NUMERO_DOCUMENTO,
    doc.CANCELAMENTO,
    doc.DATA_CANC,
    doc.ORGANIZACAO_VENDAS,
    doc.NOME,
    doc.SOBRENOME,
    doc.NR_ID_FISCAL,
    doc.MONTANTE,
    doc.TIPO_DOC_VENDAS,
    doc.QTD_ORDEM,
    doc.STATUS_INTERFACE,
    doc.ALTERADO_POR,
    doc.MATERIAL,
    doc.RUA,
    doc.ENDERECO_EMAIL,
    doc.CODIGO_POSTAL,
    doc.NUMERO,
    doc.CIDADE,
    doc.PAIS,
    doc.MOEDA,
    doc.CRIADO_POR,
    doc.NUMERO_NFSE,
    doc.DATA_ENTRADA,
    doc.CENTRO_LUCRO,
    doc.REGIAO,
    doc.COD_DOMI_FISCAL,
    doc.DOCUMENTO_VENDAS,
    doc.NR_NOTA_FISCAL,
    CASE
        WHEN SUB.STATUS_COMPENSACAO = '9'
         AND SUB.MOTIVO_COMPENSACAO = '05'
        THEN 'INATIVO'
        ELSE 'ATIVO'
    END AS STATUS_FINANCIAMENTO_FAT,
    COUNT(sub.texto_item) AS QTD_PARCELAS,
    SUM(sub.MONTANTE_COMPENSACAO) AS MONTANTE_COMPENSACAO
FROM EQTLINFO_PRD.{SCHEMA}.finpad_notas DOC
LEFT JOIN EQTLINFO_PRD.{SCHEMA}.ITENS_FINANCEIRO SUB
    ON SUB.NUMERO_DOCUMENTO = DOC.NUMERO_DOCUMENTO
WHERE doc.Tipo_doc_vendas = 'ZPAD'
  AND TO_CHAR(doc.data_entrada,'yyyymm') = '{MES}'
GROUP BY ALL
)
SELECT EMPRESA AS "EmpresaChave", TO_VARCHAR(MANDANTE) AS "Mandante", TO_VARCHAR(NOTA) AS "Nota",
       TO_VARCHAR(NUMERO_DOCUMENTO) AS "NumeroDocumento",
       DATE_TRUNC('MONTH',TO_DATE(DATA_ENTRADA))::DATE AS "DataCompetencia",
       STATUS_FINANCIAMENTO_FAT AS "StatusFinanciamento", MOEDA AS "Moeda",
       QTD_PARCELAS AS "ParcelasTextoItemNaoNulo", MONTANTE_COMPENSACAO AS "MontanteCompensacao"
FROM ORIGEM
