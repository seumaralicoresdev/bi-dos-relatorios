-- CANDIDATO DE REVISAO: nao executado no Snowflake e nao publicado.
-- Relatorio: ultapassagem demanda; tabela proposta: FatoUltrapassagem.
-- Fonte: 6433_SQL_TEMPLATE.sql; SHA256 05e907fe2401ed57e0682339955e9ef2f8b5476c9ea6098de8150cf9c8a13f01.
-- Modo de carga: mensal_competencia. Consulte audit.json antes de usar.
-- IDs convertidos a texto, sem conversao numerica; meses como primeiro dia do mes.
-- Nao aplicar DISTINCT/ABS; regra e grao internos preservados salvo ajustes listados.
WITH ORIGEM AS (
SELECT
    '{EMP}' AS empresa,
    b.instalacao,
    a.documento_impressao,
    b.mes_referencia,
    a.mes_competencia,
    SUBSTR(NVL(DECODE(b.subclasse, ' ', NULL, b.subclasse), d.codigo_subclasse), 1, 2) AS classe,
    NVL(DECODE(b.subclasse, ' ', NULL, b.subclasse), d.codigo_subclasse) AS subclasse,
    SUBSTR(NVL(b.categoria_tarifa, d.tipo_tarifa), 1, 1) AS grupo,
    SUBSTR(NVL(b.categoria_tarifa, d.tipo_tarifa), 1, 2) AS sub_grupo_tensao,
    a.item_documento,
    c.item_documento_descricao AS descricao_item_documento,
    a.valor_faturado,
    a.valor_faturado - (a.montante_cofins + a.montante_icms + a.montante_pis) AS valor_sem_imposto
FROM (
    SELECT
        mes_competencia,
        documento_calculo,
        documento_impressao,
        item_ordenacao,
        MAX(item_documento) AS item_documento,
        SUM(consumo) AS consumo_faturado,
        SUM(receita) AS valor_faturado,
        MAX(icms) AS montante_icms,
        MAX(pis) AS montante_pis,
        MAX(cofins) AS montante_cofins
    FROM (
        SELECT
            mes_competencia,
            documento_calculo,
            documento_impressao,
            CASE WHEN item_documento <> 'SUBT' THEN item_documento END AS item_documento,
            NVL(item_ordenacao, item_documento) AS item_ordenacao,
            consumo,
            SUM(receita) AS receita,
            SUM(CASE WHEN tipo_imposto = 'MW2' THEN receita ELSE 0 END) AS icms,
            SUM(CASE WHEN tipo_imposto = 'PIS' THEN receita ELSE 0 END) AS pis,
            SUM(CASE WHEN tipo_imposto = 'COF' THEN receita ELSE 0 END) AS cofins
        FROM EQTLINFO_PRD.{SCHEMA}.itens_faturamento
        WHERE item_ordenacao IN (
            'YDGU', 'ZDGU', 'YRUF', 'ZRUF', 'YRUP', 'ZRUP', 'YDU', 'Z340', 'ZDU',
            'YDUF', 'ZDUF', 'YDUP', 'ZDUP', 'YMUE', 'ZMUE', 'YMUT', 'ZMUT',
            'YUUF', 'ZUUF', 'YUUP', 'ZUUP', 'YUUL', 'ZUUL'
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
LEFT JOIN EQTLINFO_PRD.{SCHEMA}.tab_item_documento c
    ON a.item_documento = c.item_documento
LEFT JOIN EQTLINFO_PRD.{SCHEMA}.tab_cadastro d
    ON d.instalacao = b.instalacao
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
    TO_VARCHAR(ITEM_DOCUMENTO) AS "ItemDocumento",
    TO_VARCHAR(DESCRICAO_ITEM_DOCUMENTO) AS "DescricaoItemDocumento",
    VALOR_FATURADO AS "ValorFaturado",
    VALOR_SEM_IMPOSTO AS "ValorSemImposto"
FROM ORIGEM
