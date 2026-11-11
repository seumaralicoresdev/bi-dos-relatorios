-- CANDIDATO: revisão estática de colunas, sem execução no Snowflake.
-- Validar unicidade dos joins e reconciliar totais antes de substituir a consulta.
-- Nova consulta: FatoIsencaoCabecalho; NÃO substituir a FatoIsencaoReducao por esta.
-- EXISTS seleciona documentos elegíveis sem replicar o cabeçalho por itens/municípios.
-- Exige uma linha em FATURAMENTO por mês + documento de impressão + documento de cálculo.
-- O grão desses valores é o cabeçalho de FATURAMENTO, não o item nem o município.
SELECT '{EMP}' AS "EmpresaChave",
       TO_DATE(C.MES_COMPETENCIA||'01','YYYYMMDD') AS "DataCompetencia",
       TO_VARCHAR(C.DOCUMENTO_IMPRESSAO) AS "DocumentoImpressao",
       TO_VARCHAR(C.DOCUMENTO_CALCULO) AS "DocumentoCalculo",
       TO_VARCHAR(C.INSTALACAO) AS "Instalacao",
       TO_VARCHAR(C.CONTA_CONTRATO) AS "ContaContrato",
       C.ICMS AS "ICMS", C.VALOR_FATURA AS "ValorFatura"
FROM EQTLINFO_PRD.{SCHEMA}.FATURAMENTO C
WHERE C.MES_COMPETENCIA BETWEEN '{MES_INICIO}' AND '{MES_FIM}'
  AND EXISTS (
      SELECT 1 FROM EQTLINFO_PRD.{SCHEMA}.ITENS_FATURAMENTO I
      WHERE I.MES_COMPETENCIA=C.MES_COMPETENCIA
        AND I.DOCUMENTO_IMPRESSAO=C.DOCUMENTO_IMPRESSAO
        AND I.DOCUMENTO_CALCULO=C.DOCUMENTO_CALCULO
        AND I.OPERACAO='0153'
  );
