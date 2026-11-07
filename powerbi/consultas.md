# Consumir a base local no Power BI

Estas consultas usam os Parquet privados preparados pelo processador local. Não fazem nova consulta ao Snowflake. Esta entrega não contém PBIX/PBIP e não publica relatórios.

## Configurar no Desktop

1. Instale os requisitos e gere a base conforme [operação da base comum](../docs/base-comum.md).
2. Em **Transformar dados → Gerenciar parâmetros**, crie `pBasePasta`, tipo **Texto**, com a pasta de saída, por exemplo `C:\RelatoriosCorporativos\saidas`. Ela deve conter `current.json`; não informe a pasta de entrada nem um snapshot específico.
3. Crie uma consulta em branco, abra o **Editor Avançado** e cole [fnBaseComum.m](fnBaseComum.m). Nomeie a consulta `fnBaseComum` e desabilite sua carga.
4. Para inspecionar uma família, crie outra consulta com `= fnBaseComum("clientes_cativos")`. Use o `report_id` do catálogo, respeitando minúsculas e sublinhados. Os detalhes incluem informações pessoais: habilite a carga apenas das tabelas necessárias e configure a fonte como privada.
5. Crie `FatoFaturamento` com [FatoFaturamento.m](FatoFaturamento.m). Ela combina `clientes_cativos` e `clientes_livres`, agrega as dimensões comuns e mantém os nomes esperados pelas medidas financeiras anteriores.
6. Antes de validar os totais, examine `coverage.json` dentro do snapshot indicado por `current.json`. Uma empresa em `aguardando_arquivo_separado` continua com valor indisponível. Partes em `partes_recebidas_cobertura_nao_confirmada` não comprovam uma entrega completa: declare `part_number` e `parts_total` no manifesto e mantenha todas as partes `1..N` para confirmar `arquivo_recebido`. Não preencher a ausência com zero.

A função captura o ponteiro no contexto externo do leitor; `FatoFaturamento` compartilha esse leitor entre Cativo e Livre na mesma avaliação. O conector valida `schema_version = 1` e a referência relativa `snapshots/<id>`, enumera a pasta Parquet do snapshot e filtra o componente exato do relatório antes de executar `Parquet.Document`. Partições com esquemas diferentes ou sem metadados obrigatórios interrompem a atualização. Um relatório sem partições também gera erro explícito; não produz tabela de movimentos zero. Falhas de leitura não são descartadas silenciosamente.

Os arquivos de um snapshot são imutáveis. Mantenha os snapshots anteriores enquanto houver atualizações em execução; a limpeza manual de uma pasta ainda em uso pode interromper a leitura. O ponteiro é ativado pelo processador somente depois de todas as exportações terminarem. Evite trocar o snapshot durante uma atualização de várias consultas do Desktop para que elas usem a mesma versão.

## Colunas e grão

`fnBaseComum` preserva as colunas de origem normalizadas, incluindo os identificadores como texto e os zeros à esquerda. No consumo próprio, os dois cabeçalhos originais `NUMERO` são publicados como `NUMERO_FATURA` e `NUMERO_ENDERECO`. Conversão posterior para texto não recupera zeros que já tenham sido removidos antes da ingestão; confira a representação na planilha de origem.

Toda linha detalhada também contém:

| Campo | Significado / tipo |
| --- | --- |
| `__empresa` | Empresa validada, como `EQTL_MA`; texto |
| `__competencia_remessa` | Mês da entrega, `YYYYMM`; texto |
| `__periodo_dados` | Mês efetivo do registro, `YYYYMM`; texto |
| `__source_file` / `__source_sheet` | Arquivo e aba de origem; texto |
| `__source_row` | Linha da planilha; inteiro de 64 bits |

`FatoFaturamento` publica `EmpresaChave`, `CompetenciaRemessa`, `DataCompetencia`, `DataReferencia`, `Mercado`, `Grupo`, `SubGrupoTensao`, `CategoriaTarifa`, `ItemDocumento`, `DescricaoItemDocumento`, `Etapa`, `CNR`, `ClasseOrigem`, `ValorFaturado`, `ConsumoOrigem`, `COFINS`, `ICMS`, `PIS` e `ValorSemImposto`.

- `DataCompetencia` vem de `MES_COMPETENCIA`; `DataReferencia`, de `MES_REFERENCIA`. São o primeiro dia do mês, sem depender da configuração regional. A competência da remessa permanece separada em `CompetenciaRemessa`.
- `ClasseOrigem` vem de `CLASSE_PRINCIPAL` no mercado **Cativo** e de `CLASSE` no **Livre**. `Mercado` faz parte do agrupamento. Um mapa de negócio validado é necessário antes de criar uma classe padronizada entre mercados.
- O agrupamento mantém todas as dimensões comuns do pacote anterior, acrescidas da remessa. Os identificadores individuais dos livres não integram esta fato agregada. Não contar clientes a partir dela.
- Os valores são `type number`, coerentes com o `float64` da base, sem arredondamento imposto por `Currency.Type`. Valide tolerância contábil antes de usar resultados como conciliação financeira. Somas sem observação permanecem nulas; zero efetivamente observado continua zero.
- Remessas diferentes podem conter os mesmos períodos de dados. Selecione uma remessa coerente com a análise; não some automaticamente várias entregas do mesmo período. Não some famílias financeiras sobrepostas em um total geral.

As medidas financeiras anteriores que usam esses aliases podem ser reaproveitadas após validação. As medidas de cobertura do pacote anterior dependem de uma `FatoControleCarga` que não é criada por estas consultas. `coverage.json` registra cobertura por relatório, empresa e remessa: não trate sua presença como conciliação financeira ou converta automaticamente para `CargaValida = TRUE`.

## Atualização e validação

No Desktop, execute novamente o preparador antes de **Atualizar** e confira ponteiro, cobertura, empresas, remessas, tipos e totais de controle. Para manter histórico, selecione a entrada recursiva com todas as pastas de remessa identificadas por `YYYYMM`, sem `--delivery-month`, ou um manifesto com todas as entradas aprovadas e seus meses explícitos. Em modo `--input`, essa flag prevalece sobre os nomes/caminhos e fixa a remessa de todos os arquivos selecionados. Cada execução recompõe o conjunto selecionado; executar o `.bat` apenas com o mês novo não acrescenta os meses antigos ao snapshot. O código M recebeu revisão estática; a execução no Power BI Desktop não foi verificada nesta entrega.

No Power BI Service, arquivos locais exigem um gateway configurado, acesso da conta do serviço à pasta e compatibilidade do conector Parquet. A configuração e a homologação do agendamento são posteriores; o `.bat` local não executa no Service automaticamente.

Netlify e outros hosts web não leem a pasta local nem executam este Power Query. Uma aplicação futura poderá consumir os JSON agregados privados mediante definição de acesso e publicação aprovada. Os JSON continuam sendo informações corporativas; não os coloque em um diretório público para testar.
