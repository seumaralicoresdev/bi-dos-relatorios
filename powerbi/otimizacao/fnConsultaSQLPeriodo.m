// Piloto para consultas preparadas com {MES_INICIO} e {MES_FIM}.
// Não substitui fnConsultaSQL. Requer pPastaSQL, pServidorSnowflake e pWarehouse.
(ArquivoRelativo as text, Empresa as text, MesInicio as text, MesFim as text) as table =>
let
    Permitidas = {"EQTL_MA", "EQTL_PA", "EQTL_PI", "EQTL_AL", "EQTL_AP", "EQTL_RS"},
    EmpresaValidada = if List.Contains(Permitidas, Empresa) then Empresa
        else error "Distribuidora inválida.",
    ValidaMes = (Mes as text) as text =>
        if Text.Length(Mes) <> 6 or Text.Select(Mes, {"0".."9"}) <> Mes then
            error "Informe competência em YYYYMM."
        else
            let Data = try #date(Number.FromText(Text.Start(Mes, 4), "en-US"),
                                Number.FromText(Text.End(Mes, 2), "en-US"), 1)
            in if Data[HasError] then error "Competência inválida." else Mes,
    Inicio = ValidaMes(MesInicio),
    Fim = ValidaMes(MesFim),
    InicioValidado = if Inicio <= Fim then Inicio else error "Mês inicial posterior ao final.",
    TextoSQL = Text.FromBinary(File.Contents(pPastaSQL & "/" & ArquivoRelativo), TextEncoding.Utf8),
    Modelo = if Text.Contains(TextoSQL, "{MES_INICIO}")
        and Text.Contains(TextoSQL, "{MES_FIM}")
        and not Text.Contains(TextoSQL, "{MES}") then TextoSQL
        else error "Use uma consulta preparada para intervalo; o SQL mensal antigo não é compatível.",
    Regras = {
        {"{EMP}", EmpresaValidada}, {"{SCHEMA}", EmpresaValidada},
        {"{MES_INICIO}", InicioValidado}, {"{MES_FIM}", Fim}
    },
    SQL = List.Accumulate(Regras, Modelo, (Texto, Par) => Text.Replace(Texto, Par{0}, Par{1})),
    // Sem Implementation: compatível com a assinatura do conector mostrada pelo usuário.
    Conexao = Snowflake.Databases(pServidorSnowflake, pWarehouse),
    Banco = Conexao{[Name="SB_FATURAMENTO", Kind="Database"]}[Data],
    Resultado = Value.NativeQuery(Banco, SQL, null, [EnableFolding=true])
in
    Resultado
