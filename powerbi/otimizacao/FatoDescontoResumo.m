// Piloto: pMesInicio e pCompetencia são parâmetros de texto YYYYMM.
// Há uma chamada por empresa para o período inteiro, sem laço adicional por mês.
let
    Empresas = {"EQTL_MA", "EQTL_PA", "EQTL_PI", "EQTL_AL", "EQTL_AP", "EQTL_RS"},
    Resultados = List.Transform(
        Empresas,
        (EmpresaAtual) => fnConsultaSQLPeriodo(
            "modelo/02_fato_desconto_resumo.sql",
            EmpresaAtual,
            Text.From(pMesInicio),
            Text.From(pCompetencia)
        )
    ),
    Combinado = Table.Combine(Resultados),
    Tipado = Table.TransformColumnTypes(Combinado, {
        {"EmpresaChave", type text}, {"DataCompetencia", type date},
        {"ItemOrdenacao", type text}, {"ItemDocumento", type text},
        {"SubOperacao", type text}, {"MarcadorGDOrigem", type text},
        {"CategoriaTarifa", type text}, {"Subclasse", type text},
        {"ValorDescontoAssinado", type number}, {"LinhasOrigem", Int64.Type}
    }, "en-US")
in
    Tipado
