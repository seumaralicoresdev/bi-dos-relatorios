-- CANDIDATO DE REVISAO: nao executado no Snowflake e nao publicado.
-- Relatorio: clietes livres; tabela proposta: FatoClientesLivres.
-- Fonte: 3569_SQL_TEMPLATE.sql; SHA256 7cd338ac25cae48fc034c877e8ab53e2a8d526c8e08d6da5551c0c6cc1933ffc.
-- Modo de carga: mensal_competencia. Consulte audit.json antes de usar.
-- IDs convertidos a texto, sem conversao numerica; meses como primeiro dia do mes.
-- Nao aplicar DISTINCT/ABS; regra e grao internos preservados salvo ajustes listados.
WITH ORIGEM AS (
SELECT EMPRESA,
       INSTALACAO,
       DOCUMENTO_IMPRESSAO,
       NUMERO_FATURA,
       CONTA_CONTRATO,
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
       VALOR_sem_imposto
FROM (
       SELECT A.empresa, A.instalacao, documento_impressao, numero_fatura, A.conta_contrato, mes_referencia, mes_competencia, nvl(classe,substr(nvl(CL2.classe_principal,cl.classe_principal),1,2)) AS classe,
       cnr, nvl(grupo,grupo_tensao) AS grupo, substr(nvl(cod_categoria_tarifa,tipo_tarifa),1,2) AS sub_grupo_tensao, ETAPA, nvl(cod_categoria_tarifa,tipo_tarifa) AS cod_categoria_tarifa,
       A.cliente_livre, max(a.item_documento) as item_documento, substr(max(a.item_documento||'  '||TEXT30),7,100) AS descricao_item_documento, documento_calculo, item_ordenacao,
             nvl(sum(consumo),0) AS consumo_faturado,
             nvl(sum(receita),0) valor_faturado,
             nvl(max(icms),0) montante_icms,
             nvl(max(pis),0) montante_pis,
             nvl(max(cofins),0) montante_cofins,
             nvl(sum(receita),0)-(nvl(max(icms),0)+nvl(max(pis),0)+nvl(max(cofins),0)) AS VALOR_sem_imposto
         FROM
             (
                select '{EMP}' as empresa,
                  b.instalacao,
                  a.documento_impressao,
                  b.fatura as numero_fatura,
                  b.conta_contrato,
                  b.mes_referencia,
                  a.mes_competencia,
                  substr(b.subclasse,1,2) as classe,
                  b.subclasse,
                    b.cnr,
                    b.grupo,
                    substr(b.categoria_tarifa,1,2) as sub_grupo_tensao,
                    b.categoria_tarifa as cod_categoria_tarifa,
                    b.cliente_livre,
                    b.etapa,
                    consumo,
                    case when item_documento <> 'SUBT' then item_documento end as item_documento,
                    a.documento_calculo,
                   nvl(item_ordenacao, item_documento) as item_ordenacao,
                   sum(receita) as receita,
                   (SUM(case when tipo_imposto = 'MW2' THEN RECEITA END)) ICMS,
                   (SUM(case when tipo_imposto = 'PIS' THEN RECEITA END)) PIS,
                   (SUM(case when tipo_imposto = 'COF' THEN RECEITA END)) COFINS
                    from EQTLINFO_PRD.{PRD_SCHEMA}.FATURAMENTO b
                         inner join EQTLINFO_PRD.{PRD_SCHEMA}.ITENS_FATURAMENTO A on a.mes_competencia = b.mes_competencia
                                                                            and a.documento_impressao = b.documento_impressao
                                                                             and a.documento_calculo = b.documento_calculo
                                                                             and flag in ('C', 'R')
                   where 1=1
                     AND b.MES_COMPETENCIA = '{MES}'
                     AND cliente_livre = 'X'
                   group by ALL
                  ) a
  left join EQTLINFO_RAW.{RAW_SCHEMA}.TE835T c on a.item_documento = c.belzart AND c.spras = 'P' and c.mandt in ('401','402','403','404','405','406')
    LEFT JOIN EQTLINFO_PRD.{PRD_SCHEMA}.TAB_CADASTRO CAD ON CAD.INSTALACAO = a.INSTALACAO
   LEFT JOIN SB_FATURAMENTO.EQTL_RS.DESCRICAO_CLASSE_SUBCLASSE CL ON CL.SUBCLASSE = NVL(DECODE(A.SUBCLASSE,' ',NULL,A.SUBCLASSE),CAD.CODIGO_SUBCLASSE)
   LEFT JOIN EQTLINFO_PRD.{PRD_SCHEMA}.TAB_DESCRICAO_CLASSE CL2 ON CL2.SUBCLASSE = NVL(DECODE(A.SUBCLASSE,' ',NULL,A.SUBCLASSE),CAD.CODIGO_SUBCLASSE)
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
    VALOR_SEM_IMPOSTO AS "ValorSemImposto",
    'Livre' AS "Mercado"
FROM ORIGEM
