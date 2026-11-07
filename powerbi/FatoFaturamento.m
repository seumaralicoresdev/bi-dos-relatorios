// Requer fnBaseComum e o parâmetro texto pBasePasta.
// A remessa permanece uma dimensão: selecione uma remessa comparável antes de somar períodos.
let
    // Compartilhar a closure mantém Cativo e Livre no mesmo snapshot desta avaliação.
    LerSnapshot = fnBaseComum,
    InicioMes = (Valor as nullable text) as nullable date =>
        if Valor = null or Text.Trim(Valor) = "" then null
        else if Text.Length(Valor) <> 6 or Text.Select(Valor, {"0".."9"}) <> Valor then
            error Error.Record("BaseComum.Mes", "Competência do registro deve estar em YYYYMM.", Valor)
        else #date(Number.FromText(Text.Start(Valor, 4), "en-US"), Number.FromText(Text.End(Valor, 2), "en-US"), 1),
    SomarObservados = (Valores as list) as nullable number =>
        let Observados = List.RemoveNulls(Valores)
        in if List.IsEmpty(Observados) then null else List.Sum(Observados),
    Preparar = (Fonte as table, MercadoNome as text, ColunaClasse as text) as table =>
        let
            Colunas = {"__empresa", "__competencia_remessa", "MES_COMPETENCIA", "MES_REFERENCIA",
                "GRUPO", "SUB_GRUPO_TENSAO", "COD_CATEGORIA_TARIFA", "ITEM_DOCUMENTO",
                "DESCRICAO_ITEM_DOCUMENTO", "ETAPA", "CNR", ColunaClasse,
                "VALOR_FATURADO", "CONSUMO_FATURADO", "MONTANTE_COFINS", "MONTANTE_ICMS", "MONTANTE_PIS", "VALOR_SEM_IMPOSTO"},
            Ausentes = List.Difference(Colunas, Table.ColumnNames(Fonte)),
            Projetado = if List.IsEmpty(Ausentes) then Table.SelectColumns(Fonte, Colunas) else
                error Error.Record("BaseComum.Faturamento", "Colunas obrigatórias ausentes em " & MercadoNome & ".", Ausentes),
            Renomeado = Table.RenameColumns(Projetado, {
                {"__empresa", "EmpresaChave"}, {"__competencia_remessa", "CompetenciaRemessa"},
                {"GRUPO", "Grupo"}, {"SUB_GRUPO_TENSAO", "SubGrupoTensao"},
                {"COD_CATEGORIA_TARIFA", "CategoriaTarifa"}, {"ITEM_DOCUMENTO", "ItemDocumento"},
                {"DESCRICAO_ITEM_DOCUMENTO", "DescricaoItemDocumento"}, {"ETAPA", "Etapa"}, {ColunaClasse, "ClasseOrigem"},
                {"VALOR_FATURADO", "ValorFaturado"}, {"CONSUMO_FATURADO", "ConsumoOrigem"},
                {"MONTANTE_COFINS", "COFINS"}, {"MONTANTE_ICMS", "ICMS"}, {"MONTANTE_PIS", "PIS"},
                {"VALOR_SEM_IMPOSTO", "ValorSemImposto"}
            }),
            ComCompetencia = Table.AddColumn(Renomeado, "DataCompetencia", each InicioMes([MES_COMPETENCIA]), type nullable date),
            ComReferencia = Table.AddColumn(ComCompetencia, "DataReferencia", each InicioMes([MES_REFERENCIA]), type nullable date),
            ComMercado = Table.AddColumn(ComReferencia, "Mercado", each MercadoNome, type text),
            SemMesesOriginais = Table.RemoveColumns(ComMercado, {"MES_COMPETENCIA", "MES_REFERENCIA"})
        in SemMesesOriginais,
    Cativos = Preparar(LerSnapshot("clientes_cativos"), "Cativo", "CLASSE_PRINCIPAL"),
    Livres = Preparar(LerSnapshot("clientes_livres"), "Livre", "CLASSE"),
    Combinado = Table.Combine({Cativos, Livres}),
    Tipado = Table.TransformColumnTypes(Combinado, {
        {"EmpresaChave", type text}, {"CompetenciaRemessa", type text},
        {"DataCompetencia", type date}, {"DataReferencia", type date}, {"Mercado", type text},
        {"Grupo", type text}, {"SubGrupoTensao", type text}, {"CategoriaTarifa", type text},
        {"ItemDocumento", type text}, {"DescricaoItemDocumento", type text}, {"Etapa", type text},
        {"CNR", type text}, {"ClasseOrigem", type text},
        {"ValorFaturado", type number}, {"ConsumoOrigem", type number},
        {"COFINS", type number}, {"ICMS", type number}, {"PIS", type number}, {"ValorSemImposto", type number}
    }, "en-US"),
    Dimensoes = {"EmpresaChave", "CompetenciaRemessa", "DataCompetencia", "DataReferencia", "Mercado",
        "Grupo", "SubGrupoTensao", "CategoriaTarifa", "ItemDocumento", "DescricaoItemDocumento", "Etapa", "CNR", "ClasseOrigem"},
    // Livre perde os identificadores individuais neste modelo agregado. Não contar clientes.
    // ClasseOrigem é a classe própria de cada mercado; Mercado integra sempre a chave.
    Agregado = Table.Group(Tipado, Dimensoes, {
        {"ValorFaturado", each SomarObservados([ValorFaturado]), type nullable number},
        {"ConsumoOrigem", each SomarObservados([ConsumoOrigem]), type nullable number},
        {"COFINS", each SomarObservados([COFINS]), type nullable number},
        {"ICMS", each SomarObservados([ICMS]), type nullable number},
        {"PIS", each SomarObservados([PIS]), type nullable number},
        {"ValorSemImposto", each SomarObservados([ValorSemImposto]), type nullable number}
    })
in
    Agregado
