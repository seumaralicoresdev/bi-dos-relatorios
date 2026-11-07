// Criar parâmetro de texto pBasePasta com a pasta que contém current.json.
// Consulta de função: desabilitar carga. Os detalhes são privados.
// O let externo captura um único ponteiro por avaliação desta função.
let
    BarraInvertida = Character.FromNumber(92),
    NormalizarCaminho = (Caminho as text) as text => Text.Replace(Caminho, BarraInvertida, "/"),
    PastaInformada = Text.TrimEnd(Text.Trim(pBasePasta), {"/", BarraInvertida}),
    PastaBase = if PastaInformada <> "" then PastaInformada else
        error Error.Record("BaseComum.Parametro", "Informe pBasePasta, a pasta que contém current.json.", null),
    Ponteiro = Json.Document(Binary.Buffer(File.Contents(PastaBase & "/current.json"))),
    PonteiroValidado = if not Value.Is(Ponteiro, type record) then
        error Error.Record("BaseComum.Ponteiro", "current.json deve conter um objeto JSON.", null)
        else if not Record.HasFields(Ponteiro, {"schema_version", "snapshot"}) then
        error Error.Record("BaseComum.Ponteiro", "current.json não contém schema_version e snapshot.", null)
        else if Ponteiro[schema_version] <> 1 or not Value.Is(Ponteiro[snapshot], type text) then
        error Error.Record("BaseComum.Ponteiro", "Versão ou referência de snapshot não suportada.", null)
        else Ponteiro,
    PartesSnapshot = Text.Split(PonteiroValidado[snapshot], "/"),
    SnapshotRelativo = if List.Count(PartesSnapshot) = 2
        and PartesSnapshot{0} = "snapshots"
        and PartesSnapshot{1} <> ""
        and Text.Select(PartesSnapshot{1}, {"a".."z", "A".."Z", "0".."9", "-", "_"}) = PartesSnapshot{1}
        then PonteiroValidado[snapshot] else
        error Error.Record("BaseComum.Ponteiro", "snapshot deve ser um caminho relativo snapshots/<id> válido.", null),
    RaizParquet = NormalizarCaminho(PastaBase & "/" & SnapshotRelativo & "/parquet"),
    LerRelatorio = (Relatorio as text) as table =>
        let
            RelatorioValido = if Relatorio <> "" and Text.Select(Relatorio, {"a".."z", "0".."9", "_"}) = Relatorio
                then Relatorio else
                error Error.Record("BaseComum.Relatorio", "Use o identificador exato do relatório, por exemplo clientes_cativos.", Relatorio),
            Arquivos = Folder.Files(RaizParquet),
            // Filtrar o SEGMENTO do relatório e o layout completo ANTES de abrir qualquer Parquet.
            Selecionados = Table.SelectRows(Arquivos, each
                let
                    Caminho = NormalizarCaminho([Folder Path]) & [Name],
                    Relativo = Text.Range(Caminho, Text.Length(RaizParquet) + 1),
                    Partes = Text.Split(Relativo, "/")
                in
                    List.Count(Partes) = 5
                    and List.Contains({"contabilidade", "tributario"}, Partes{0})
                    and Partes{1} = RelatorioValido
                    and Text.Length(Partes{2}) = 6
                    and Text.Select(Partes{2}, {"0".."9"}) = Partes{2}
                    and List.Contains({"EQTL_MA", "EQTL_PA", "EQTL_PI", "EQTL_AL", "EQTL_AP", "EQTL_RS"}, Partes{3})
                    and Partes{4} = "dados.parquet"),
            Conteudos = if Table.IsEmpty(Selecionados) then
                error Error.Record("BaseComum.SemParticoes", "Relatório sem partições neste snapshot. Consulte coverage.json; ausência não significa zero.", RelatorioValido)
                else Selecionados[Content],
            Tabelas = List.Transform(Conteudos, each Parquet.Document(Binary.Buffer(_))),
            Metadados = {"__empresa", "__competencia_remessa", "__periodo_dados", "__source_file", "__source_sheet", "__source_row"},
            ColunasReferencia = Table.ColumnNames(Tabelas{0}),
            Verificadas = List.Transform(Tabelas, (Tabela) =>
                if not List.IsEmpty(List.Difference(Metadados, Table.ColumnNames(Tabela))) then
                    error Error.Record("BaseComum.Esquema", "Partição sem todos os metadados obrigatórios.", RelatorioValido)
                else if not List.IsEmpty(List.Difference(ColunasReferencia, Table.ColumnNames(Tabela)))
                    or not List.IsEmpty(List.Difference(Table.ColumnNames(Tabela), ColunasReferencia)) then
                    error Error.Record("BaseComum.Esquema", "Partições do mesmo relatório têm colunas diferentes; revise a geração da base.", RelatorioValido)
                else Tabela),
            Combinado = Table.Combine(Verificadas),
            // O normalizador grava IDs como texto no Parquet. Não há detecção automática de tipos.
            // Esta lista mantém os identificadores e os meses como texto também no consumo.
            ColunasTexto = {
                "__empresa", "__competencia_remessa", "__periodo_dados", "__source_file", "__source_sheet",
                "EMPRESA", "ESTADO", "INSTALACAO", "CONTA_CONTRATO", "CONTRATO", "FATURA",
                "DOCUMENTO_IMPRESSAO", "DOCUMENTO_CALCULO", "NUMERO_FATURA", "NUMERO_ENDERECO",
                "NUMERO_NF3E", "CPF", "CNPJ", "CPF_CNPJ", "CHAVE_ACESSO", "CHAVE_RECONCILIACAO",
                "CONTRATO_GERADORA", "CONTA_CONTRATO_GERADORA", "ITEM_ORDENACAO", "ITEM_DOCUMENTO",
                "MES_COMPETENCIA", "MES_REFERENCIA", "COMPETENCIA", "REFERENCIA", "MES_LANCAMENTO",
                "MES", "MES_ORIGEM_CREDITO", "CODIGO_CLASSE", "CLASSE", "CLASSE_PRINCIPAL", "SUBCLASSE",
                "GRUPO", "SUB_GRUPO_TENSAO", "COD_CATEGORIA_TARIFA", "CATEGORIA_TARIFA", "CNR", "ETAPA"
            },
            TiposTexto = List.Transform(List.Intersect({ColunasTexto, Table.ColumnNames(Combinado)}), each {_, type text}),
            Tipado = Table.TransformColumnTypes(Combinado, TiposTexto & {{"__source_row", Int64.Type}}, "en-US")
        in
            Tipado
in
    LerRelatorio
