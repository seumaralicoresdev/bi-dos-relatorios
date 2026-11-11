-- CANDIDATO DE REVISAO: nao executado no Snowflake e nao publicado.
-- Relatorio: reativos excedentes; tabela proposta: FatoReativos.
-- Fonte: 5729_SQL_TEMPLATE.sql; SHA256 8cb34ede74ab663e4b7da84334a7847ff119d0b9224ec24ae8b9cb14ca1f4a12.
-- Modo de carga: mensal_competencia. Consulte audit.json antes de usar.
-- IDs convertidos a texto, sem conversao numerica; meses como primeiro dia do mes.
-- Nao aplicar DISTINCT/ABS; regra e grao internos preservados salvo ajustes listados.
WITH ORIGEM AS (
-- RELATÓRIO EXCEDENTE REATIVO
SELECT
    '{EMP}' AS empresa,
    B.instalacao,
    a.documento_impressao,
    mes_referencia,
    a.mes_competencia,
    SUBSTR(NVL(DECODE(B.subclasse, ' ', NULL, B.SUBCLASSE), CAD.CODIGO_SUBCLASSE), 1, 2) AS classe,
    NVL(DECODE(B.subclasse, ' ', NULL, B.SUBCLASSE), CAD.CODIGO_SUBCLASSE) AS subclasse,
    SUBSTR(NVL(DECODE(B.CATEGORIA_TARIFA, ' ', NULL, B.CATEGORIA_TARIFA), CAD.TIPO_TARIFA), 1, 1) AS grupo,
    SUBSTR(NVL(DECODE(B.CATEGORIA_TARIFA, ' ', NULL, B.CATEGORIA_TARIFA), CAD.TIPO_TARIFA), 1, 2) AS sub_grupo_tensao,
    a.item_ordenacao,
    a.item_documento,
    ITEM_DOCUMENTO_DESCRICAO AS descricao_item_documento,
    valor_faturado,
    valor_faturado - (montante_cofins + montante_icms + montante_pis) AS valor_sem_imposto
FROM (
    SELECT
        mes_competencia,
        documento_calculo,
        documento_impressao,
        MAX(item_documento) AS item_documento,
        SUM(consumo) AS consumo_faturado,
        item_ordenacao,
        SUM(receita) AS valor_faturado,
        SUM(icms) AS montante_icms,
        SUM(pis) AS montante_pis,
        SUM(cofins) AS montante_cofins
    FROM (
        SELECT
            mes_COMPETENCIA,
            documento_calculo,
            documento_impressao,
            CASE WHEN item_documento <> 'SUBT' THEN item_documento END AS item_documento,
            NVL(item_ordenacao, item_documento) AS item_ordenacao,
            consumo,
            SUM(receita) AS receita,
            (SUM(CASE WHEN tipo_imposto = 'MW2' THEN RECEITA ELSE 0 END)) AS ICMS,
            (SUM(CASE WHEN tipo_imposto = 'PIS' THEN RECEITA ELSE 0 END)) AS PIS,
            (SUM(CASE WHEN tipo_imposto = 'COF' THEN RECEITA ELSE 0 END)) AS COFINS
        FROM EQTLINFO_PRD.{SCHEMA}.itens_faturamento
        WHERE ITEM_ordenacao IN (
            'ZCRF', 'ZCRP', 'ZCRR', 'ZCRE', 'ZDRE', 'ZDRF', 'ZDRP',
            'YCRE', 'YCRF', 'YCRI', 'YCRP', 'YCRR', 'YDRE', 'YDRF', 'YDRP',
            'YPD1', 'YPD2', 'YPD3', 'YTR1', 'YTR2', 'YTR3', 'YTR4', 'YTR5',
            'Z565', 'Z566', 'Z567', 'ZCRE', 'ZCRF', 'ZCRI', 'ZCRP', 'ZCRR',
            'ZDRE', 'ZDRF', 'ZDRP', 'ZPD1', 'ZPD2', 'ZPD3', 'ZTR1', 'ZTR2',
            'ZTR3', 'ZTR4', 'ZTR5', 'ZCFI', 'ZCNI'
        )
        AND flag IN ('C', 'R')
        AND mes_competencia = '{MES}'
        GROUP BY
            consumo,
            mes_competencia,
            CASE WHEN item_documento <> 'SUBT' THEN item_documento END,
            NVL(item_ordenacao, item_documento),
            documento_calculo,
            documento_impressao
    ) zxc
    GROUP BY
        mes_competencia,
        documento_calculo,
        documento_impressao,
        item_ordenacao
) a
INNER JOIN EQTLINFO_PRD.{SCHEMA}.faturamento b
    ON a.mes_competencia = b.mes_competencia
    AND a.documento_impressao = b.documento_impressao
    AND a.documento_calculo = b.documento_calculo
LEFT JOIN EQTLINFO_PRD.{SCHEMA}.TAB_item_documento c
    ON a.item_documento = c.item_documento
INNER JOIN EQTLINFO_PRD.{SCHEMA}.TAB_CADASTRO CAD
    ON CAD.INSTALACAO = B.INSTALACAO
)
SELECT
    TO_VARCHAR(EMPRESA) AS "EmpresaChave",
    TO_VARCHAR(INSTALACAO) AS "Instalacao",
    TO_VARCHAR(DOCUMENTO_IMPRESSAO) AS "DocumentoImpressao",
    TRY_TO_DATE(TO_VARCHAR(MES_REFERENCIA) || '01', 'YYYYMMDD') AS "DataReferencia",
    TRY_TO_DATE(TO_VARCHAR(MES_COMPETENCIA) || '01', 'YYYYMMDD') AS "DataCompetencia",
    TO_VARCHAR(CLASSE) AS "ClasseOrigem",
    TO_VARCHAR(SUBCLASSE) AS "Subclasse",
    TO_VARCHAR(GRUPO) AS "Grupo",
    TO_VARCHAR(SUB_GRUPO_TENSAO) AS "SubGrupoTensao",
    TO_VARCHAR(ITEM_ORDENACAO) AS "ItemOrdenacao",
    TO_VARCHAR(ITEM_DOCUMENTO) AS "ItemDocumento",
    TO_VARCHAR(DESCRICAO_ITEM_DOCUMENTO) AS "DescricaoItemDocumento",
    VALOR_FATURADO AS "ValorFaturado",
    VALOR_SEM_IMPOSTO AS "ValorSemImposto"
FROM ORIGEM
