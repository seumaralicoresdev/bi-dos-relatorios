-- CANDIDATO DE REVISAO: nao executado no Snowflake e nao publicado.
-- Relatorio: relatorio tusd geradores; tabela proposta: FatoTUSDGeradores.
-- Fonte: 2593_SQL_TEMPLATE.sql; SHA256 85550da056d4195aeb137ad6efcee8a1824f69e46a5eb9c10d15f4d347a680af.
-- Modo de carga: mensal_referencia_mes_anterior. Consulte audit.json antes de usar.
-- IDs convertidos a texto, sem conversao numerica; meses como primeiro dia do mes.
-- Nao aplicar DISTINCT/ABS; regra e grao internos preservados salvo ajustes listados.
-- Adaptação de placeholders ao fnConsultaSQL; regra previous_competencia preservada em expressão SQL -1 mês.
-- {MES}=202610 seleciona referencia 202609; DataCompetencia de saida nao e filtrada.
WITH ORIGEM AS (
SELECT
    EMPRESA,
    INSTALACAO,
    DOCUMENTO_IMPRESSAO,
    NUMERO_FATURA,
    CONTA_CONTRATO,
    DATA_CRIACAO_IMPRESSAO,
    CONTA_MES,
    MES_REFERENCIA,
    MES_COMPETENCIA,
    CLASSE,
    CNR,
    GRUPO,
    SUB_GRUPO_TENSAO,
    COD_CATEGORIA_TARIFA,
    CLIENTE_LIVRE,
    ITEM_DOCUMENTO,
    DESCRICAO_ITEM_DOCUMENTO,
    ETAPA,
    VALOR_FATURADO,
    CONSUMO_FATURADO,
    MONTANTE_COFINS,
    MONTANTE_ICMS,
    MONTANTE_PIS,
    VALOR_SEM_IMPOSTO
FROM (
    SELECT
        A.EMPRESA,
        A.INSTALACAO,
        A.DOCUMENTO_IMPRESSAO,
        A.NUMERO_FATURA,
        A.CONTA_CONTRATO,
        A.DATA_CRIACAO_IMPRESSAO,
        A.CONTA_MES,
        A.MES_REFERENCIA,
        A.MES_COMPETENCIA,
        A.CLASSE,
        A.CNR,
        NVL(
            SUBSTR(
                A.SUB_GRUPO_TENSAO,
                1,
                1
            ),
            CAD.GRUPO_TENSAO
        ) AS GRUPO,
        SUBSTR(
            NVL(
                A.COD_CATEGORIA_TARIFA,
                CAD.TIPO_TARIFA
            ),
            1,
            2
        ) AS SUB_GRUPO_TENSAO,
        NVL(
            A.COD_CATEGORIA_TARIFA,
            CAD.TIPO_TARIFA
        ) AS COD_CATEGORIA_TARIFA,
        A.CLIENTE_LIVRE,
        A.ETAPA,
        MAX(A.ITEM_DOCUMENTO) AS ITEM_DOCUMENTO,
        SUBSTR(
            MAX(
                A.ITEM_DOCUMENTO
                || '  '
                || C.TEXT30
            ),
            7,
            100
        ) AS DESCRICAO_ITEM_DOCUMENTO,
        A.DOCUMENTO_CALCULO,
        A.ITEM_ORDENACAO,
        NVL(
            SUM(A.CONSUMO),
            0
        ) AS CONSUMO_FATURADO,
        NVL(
            SUM(A.RECEITA),
            0
        ) AS VALOR_FATURADO,
        NVL(
            MAX(A.ICMS),
            0
        ) AS MONTANTE_ICMS,
        NVL(
            MAX(A.PIS),
            0
        ) AS MONTANTE_PIS,
        NVL(
            MAX(A.COFINS),
            0
        ) AS MONTANTE_COFINS,
        NVL(
            SUM(A.RECEITA),
            0
        )
        - (
            NVL(MAX(A.ICMS), 0)
            + NVL(MAX(A.PIS), 0)
            + NVL(MAX(A.COFINS), 0)
        ) AS VALOR_SEM_IMPOSTO
    FROM (
        SELECT
            '{EMP}' AS EMPRESA,
            B.INSTALACAO,
            A.DOCUMENTO_IMPRESSAO,
            B.FATURA AS NUMERO_FATURA,
            B.CONTA_CONTRATO,
            B.DATA_CRIACAO_IMPRESSAO,
            B.MES_REFERENCIA,
            TO_CHAR(
                ADD_MONTHS(
                    B.FIM_CALCULO,
                    1
                ),
                'YYYYMM'
            ) AS CONTA_MES,
            A.MES_COMPETENCIA,
            SUBSTR(
                B.SUBCLASSE,
                1,
                2
            ) AS CLASSE,
            B.SUBCLASSE,
            B.CNR,
            B.GRUPO,
            SUBSTR(
                B.CATEGORIA_TARIFA,
                1,
                2
            ) AS SUB_GRUPO_TENSAO,
            B.CATEGORIA_TARIFA AS COD_CATEGORIA_TARIFA,
            B.CLIENTE_LIVRE,
            B.ETAPA,
            A.CONSUMO,
            CASE
                WHEN A.ITEM_DOCUMENTO <> 'SUBT'
                THEN A.ITEM_DOCUMENTO
            END AS ITEM_DOCUMENTO,
            A.DOCUMENTO_CALCULO,
            NVL(
                A.ITEM_ORDENACAO,
                A.ITEM_DOCUMENTO
            ) AS ITEM_ORDENACAO,
            SUM(A.RECEITA) AS RECEITA,
            SUM(
                CASE
                    WHEN A.TIPO_IMPOSTO = 'MW2'
                    THEN A.RECEITA
                END
            ) AS ICMS,
            SUM(
                CASE
                    WHEN A.TIPO_IMPOSTO = 'PIS'
                    THEN A.RECEITA
                END
            ) AS PIS,
            SUM(
                CASE
                    WHEN A.TIPO_IMPOSTO = 'COF'
                    THEN A.RECEITA
                END
            ) AS COFINS
        FROM EQTLINFO_PRD.{PRD_SCHEMA}.FATURAMENTO B
        INNER JOIN EQTLINFO_PRD.{PRD_SCHEMA}.TAB_CADASTRO CAD0
            ON B.INSTALACAO = CAD0.INSTALACAO
        INNER JOIN EQTLINFO_PRD.{PRD_SCHEMA}.ITENS_FATURAMENTO A
            ON A.MES_COMPETENCIA = B.MES_COMPETENCIA
            AND A.DOCUMENTO_IMPRESSAO = B.DOCUMENTO_IMPRESSAO
            AND A.DOCUMENTO_CALCULO = B.DOCUMENTO_CALCULO
            AND A.FLAG IN ('C', 'R')
        WHERE
            (
                (
                    B.MES_REFERENCIA = TO_CHAR(ADD_MONTHS(TO_DATE('{MES}' || '01', 'YYYYMMDD'), -1), 'YYYYMM')
                    AND CAD0.EMPRESA <> 'D005'
                )
                OR (
                    TO_CHAR(
                        ADD_MONTHS(
                            B.FIM_CALCULO,
                            1
                        ),
                        'YYYYMM'
                    ) = TO_CHAR(ADD_MONTHS(TO_DATE('{MES}' || '01', 'YYYYMMDD'), -1), 'YYYYMM')
                    AND CAD0.EMPRESA = 'D005'
                )
            )
            AND B.CATEGORIA_TARIFA LIKE '%GER%'
            AND A.ITEM_ORDENACAO = 'ZDGR'
        GROUP BY ALL
    ) A
    LEFT JOIN EQTLINFO_RAW.{RAW_SCHEMA}.TE835T C
        ON A.ITEM_DOCUMENTO = C.BELZART
        AND C.SPRAS = 'P'
        AND C.MANDT IN ('401','402','403','404','405','406')
    LEFT JOIN EQTLINFO_PRD.{PRD_SCHEMA}.TAB_CADASTRO CAD
        ON CAD.INSTALACAO = A.INSTALACAO
    GROUP BY ALL
)
GROUP BY ALL
)
SELECT
    TO_VARCHAR(EMPRESA) AS "EmpresaChave",
    TO_VARCHAR(INSTALACAO) AS "Instalacao",
    TO_VARCHAR(DOCUMENTO_IMPRESSAO) AS "DocumentoImpressao",
    TO_VARCHAR(NUMERO_FATURA) AS "NumeroFatura",
    TO_VARCHAR(CONTA_CONTRATO) AS "ContaContrato",
    DATA_CRIACAO_IMPRESSAO AS "DataCriacaoImpressao",
    TRY_TO_DATE(TO_VARCHAR(CONTA_MES) || '01', 'YYYYMMDD') AS "DataContaMes",
    TRY_TO_DATE(TO_VARCHAR(MES_REFERENCIA) || '01', 'YYYYMMDD') AS "DataReferencia",
    TRY_TO_DATE(TO_VARCHAR(MES_COMPETENCIA) || '01', 'YYYYMMDD') AS "DataCompetencia",
    TO_VARCHAR(CLASSE) AS "ClasseOrigem",
    TO_VARCHAR(CNR) AS "CNR",
    TO_VARCHAR(GRUPO) AS "Grupo",
    TO_VARCHAR(SUB_GRUPO_TENSAO) AS "SubGrupoTensao",
    TO_VARCHAR(COD_CATEGORIA_TARIFA) AS "CategoriaTarifa",
    TO_VARCHAR(CLIENTE_LIVRE) AS "ClienteLivreOrigem",
    TO_VARCHAR(ITEM_DOCUMENTO) AS "ItemDocumento",
    TO_VARCHAR(DESCRICAO_ITEM_DOCUMENTO) AS "DescricaoItemDocumento",
    TO_VARCHAR(ETAPA) AS "Etapa",
    VALOR_FATURADO AS "ValorFaturado",
    CONSUMO_FATURADO AS "ConsumoOrigem",
    MONTANTE_COFINS AS "COFINS",
    MONTANTE_ICMS AS "ICMS",
    MONTANTE_PIS AS "PIS",
    VALOR_SEM_IMPOSTO AS "ValorSemImposto"
FROM ORIGEM
