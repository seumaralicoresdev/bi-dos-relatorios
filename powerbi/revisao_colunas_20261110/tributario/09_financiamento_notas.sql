-- CANDIDATO: revisão estática de colunas, sem execução no Snowflake.
-- Validar unicidade dos joins e reconciliar totais antes de substituir a consulta.
-- RASCUNHO: DISTINCT só elimina repetições idênticas de atributos documentais.
-- Bloquear carga se Empresa+Mandante+Nota+NumeroDocumento não for única.
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
SELECT DISTINCT TO_VARCHAR(EMPRESA) AS "EmpresaChave",
    TO_VARCHAR(NOTA) AS "Nota",
    TO_VARCHAR(MANDANTE) AS "Mandante",
    TO_VARCHAR(INSTALACAO) AS "Instalacao",
    TO_VARCHAR(CONTA_CONTRATO) AS "ContaContrato",
    TO_VARCHAR(PARCEIRO_NEGOCIO) AS "ParceiroNegocio",
    TO_VARCHAR(PEP_ODS) AS "PepOds",
    TO_VARCHAR(TIPO) AS "Tipo",
    DATA_CADASTRO AS "DataCadastroOrigem",
    TO_VARCHAR(NUMERO_DOCUMENTO) AS "NumeroDocumento",
    TO_VARCHAR(CANCELAMENTO) AS "CancelamentoOrigem",
    DATA_CANC AS "DataCancelamentoOrigem",
    TO_VARCHAR(ORGANIZACAO_VENDAS) AS "OrganizacaoVendas",
    TO_VARCHAR(NOME) AS "Nome",
    TO_VARCHAR(SOBRENOME) AS "Sobrenome",
    TO_VARCHAR(NR_ID_FISCAL) AS "NumeroIdFiscal",
    MONTANTE AS "Montante",
    TO_VARCHAR(TIPO_DOC_VENDAS) AS "TipoDocumentoVendas",
    QTD_ORDEM AS "QuantidadeOrdem",
    TO_VARCHAR(STATUS_INTERFACE) AS "StatusInterface",
    TO_VARCHAR(ALTERADO_POR) AS "AlteradoPor",
    TO_VARCHAR(MATERIAL) AS "Material",
    TO_VARCHAR(RUA) AS "Rua",
    TO_VARCHAR(ENDERECO_EMAIL) AS "EnderecoEmail",
    TO_VARCHAR(CODIGO_POSTAL) AS "CodigoPostal",
    TO_VARCHAR(NUMERO) AS "NumeroEndereco",
    TO_VARCHAR(CIDADE) AS "Cidade",
    TO_VARCHAR(PAIS) AS "Pais",
    TO_VARCHAR(MOEDA) AS "Moeda",
    TO_VARCHAR(CRIADO_POR) AS "CriadoPor",
    TO_VARCHAR(NUMERO_NFSE) AS "NumeroNFSe",
    TO_DATE(DATA_ENTRADA) AS "DataEntrada",
    TO_VARCHAR(CENTRO_LUCRO) AS "CentroLucro",
    TO_VARCHAR(REGIAO) AS "Regiao",
    TO_VARCHAR(COD_DOMI_FISCAL) AS "CodigoDomicilioFiscal",
    TO_VARCHAR(DOCUMENTO_VENDAS) AS "DocumentoVendas",
    TO_VARCHAR(NR_NOTA_FISCAL) AS "NumeroNotaFiscal",
    DATE_TRUNC('MONTH',TO_DATE(DATA_ENTRADA))::DATE AS "DataCompetencia"
FROM ORIGEM;
