-- CANDIDATO DE REVISAO: nao executado no Snowflake e nao publicado.
-- Relatorio: clientes cativos; tabela proposta: FatoClientesCativos.
-- Fonte: 0103_SQL_TEMPLATE.sql; SHA256 8ab83ec78563890420ea9aaf4338fb119623a27100dbfb4771dc18b9e897832b.
-- Modo de carga: mensal_competencia. Consulte audit.json antes de usar.
-- IDs convertidos a texto, sem conversao numerica; meses como primeiro dia do mes.
-- Nao aplicar DISTINCT/ABS; regra e grao internos preservados salvo ajustes listados.
WITH ORIGEM AS (
SELECT
    '{EMP}' as  empresa, mes_referencia, a.mes_competencia, nvl(cl2.codigo_classe,cl.codigo_classe) AS codigo_classe,
nvl(cl2.classe_principal,CL.CLASSE_PRINCIPAL) AS classe_principal, NVL(DECODE(B.SUBCLASSE,' ',NULL,B.SUBCLASSE),CAD.CODIGO_SUBCLASSE) AS subclasse,
nvl(cl2.subclasse_descricao,CL.SUBCLASSE_DESCRICAO) AS SUBCLASSE_DESCRICAO, cnr, substr(NVL(categoria_tarifa,TIPO_TARIFA),1,1) AS grupo,
substr(NVL(categoria_tarifa,TIPO_TARIFA),1,2) as sub_grupo_tensao, NVL(categoria_tarifa,TIPO_TARIFA) as cod_categoria_tarifa, b.cliente_livre, a.item_documento, TEXT30 AS descricao_item_documento, etapa,
SUM(valor_faturado) AS valor_faturado,
SUM(a.consumo_faturado) AS consumo_faturado,
SUM(montante_cofins) AS montante_cofins,
SUM(montante_icms) AS montante_icms,
SUM(montante_pis) AS montante_pis,
SUM(valor_faturado) - (SUM(montante_cofins)+SUM(montante_icms)+SUM(montante_pis)) as valor_sem_imposto
  from
       (
        select mes_competencia,  documento_calculo,  documento_impressao,  item_ordenacao,
                max(item_documento)as item_documento,
                sum(consumo)consumo_faturado,
                sum(receita) valor_faturado,
                max(NVL(icms,0)) montante_icms,
                max(NVL(pis,0)) montante_pis ,
                max(NVL(cofins,0)) montante_cofins
          from
              (
               select mes_COMPETENCIA,  documento_calculo, documento_impressao, case when item_documento <> 'SUBT' then item_documento end as item_documento,
                       nvl(item_ordenacao, item_documento) as item_ordenacao, consumo,
                       sum(receita) as receita,
                       (SUM(case when tipo_imposto = 'MW2' THEN RECEITA END)) ICMS,
                       (SUM(case when tipo_imposto = 'PIS' THEN RECEITA END)) PIS,
                       (SUM(case when tipo_imposto = 'COF' THEN RECEITA END)) COFINS
                 from EQTLINFO_PRD.{PRD_SCHEMA}.ITENS_FATURAMENTO
                where 1=1
                  AND mes_competencia = '{MES}'
                  and documento_impressao in (
                                           select b.documento_impressao
                                             from EQTLINFO_PRD.{PRD_SCHEMA}.FATURAMENTO B
                                            where 1=1
                                              AND b.mes_competencia = '{MES}'
                                              AND CLIENTE_LIVRE IS NULL
                                          )
                  and flag in ('C', 'R')
                group by ALL
                )
           group by  ALL
      )a  inner join EQTLINFO_PRD.{PRD_SCHEMA}.FATURAMENTO b on  a.mes_competencia = b.mes_competencia
                                                     and a.documento_impressao = b.documento_impressao
                                                     and a.documento_calculo = b.documento_calculo
    left join EQTLINFO_RAW.{RAW_SCHEMA}.TE835T c on a.item_documento = C.BELZART AND SPRAS = 'P' and c.mandt in ('401','402','403','404','405','406')
   LEFT JOIN EQTLINFO_PRD.{PRD_SCHEMA}.TAB_CADASTRO CAD ON CAD.INSTALACAO = B.INSTALACAO
   LEFT JOIN SB_FATURAMENTO.EQTL_RS.DESCRICAO_CLASSE_SUBCLASSE CL ON CL.SUBCLASSE = NVL(DECODE(B.SUBCLASSE,' ',NULL,B.SUBCLASSE),CAD.CODIGO_SUBCLASSE)
   LEFT JOIN EQTLINFO_PRD.{PRD_SCHEMA}.TAB_DESCRICAO_CLASSE CL2 ON CL2.SUBCLASSE = NVL(DECODE(B.SUBCLASSE,' ',NULL,B.SUBCLASSE),CAD.CODIGO_SUBCLASSE)
GROUP BY all
)
SELECT
    TO_VARCHAR(EMPRESA) AS "EmpresaChave",
    TRY_TO_DATE(TO_VARCHAR(MES_REFERENCIA) || '01', 'YYYYMMDD') AS "DataReferencia",
    TRY_TO_DATE(TO_VARCHAR(MES_COMPETENCIA) || '01', 'YYYYMMDD') AS "DataCompetencia",
    TO_VARCHAR(CODIGO_CLASSE) AS "CodigoClasse",
    TO_VARCHAR(CLASSE_PRINCIPAL) AS "ClasseOrigem",
    TO_VARCHAR(SUBCLASSE) AS "Subclasse",
    TO_VARCHAR(SUBCLASSE_DESCRICAO) AS "SubclasseDescricao",
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
    'Cativo' AS "Mercado"
FROM ORIGEM
