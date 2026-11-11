# Revisão de colunas — Tributário

Os arquivos desta pasta são candidatos de consulta derivados das fontes fornecidas. Preservam os aliases atuais usados pelas medidas e acrescentam campos que a projeção reduzida omitia. Nenhum SQL foi executado no Snowflake e nenhum PBIX foi alterado. O novo anexo de automação confirmou os sete SQL originais de Tributário, sem alteração de lógica (diferenças somente de espaços).

`audit.json` contém as 136 posições da aba TRIBUTARIO, na mesma ordem do Excel, com correspondência, situação, alias proposto e ressalvas. A comparação do modelo usa o print e os SQL do pacote: alterações feitas localmente no PBIX fora desses materiais não foram inspecionadas.

| Relatório | Resultado da comparação | Candidato |
|---|---|---|
| Consumo próprio | 23 campos omitidos; `NUMERO` aparece duas vezes no requisito e será `NumeroFatura` / `NumeroEndereco`. | `06_fato_consumo_proprio.sql` |
| Encargo COVID | Faltam mês de referência/data dos dados; consumo atual é bruto, não MWh. | `11_encargo_covid_por_documento.sql` |
| Escassez hídrica | Mesmas omissões e divergência de unidade; data dos dados vem da fonte. | `11_encargo_escassez_hidrica_por_documento.sql` |
| Isenção ICMS TUSD | Faltam 11 campos; ICMS/valor da fatura pertencem ao cabeçalho. | `13_isencao_reducao_por_documento.sql` + `13b_isencao_cabecalho.sql` |
| ICMS Injetada | Faltam seis atributos comprovados; três campos NF3E são NULL no próprio SQL legado. | `14_injetada_itens_preagregados.sql` |
| Retenção | Especificação repete Injetada, divergindo dos 13 campos do Excel real de retenções. | Bloqueado até confirmar o contrato |
| Financiamento padrão | Faltam 29 atributos; conservar nota e compensação em grãos separados. | `09_financiamento_notas.sql` + `10_financiamento_compensacao.sql` |

## Como carregar três meses

Use o mês de conferência como referência. Se `pCompetencia` for `202610`, o intervalo é `202608` a `202610`.

- **Mensais:** Consumo, Financiamento Nota/Compensação e Injetada: uma execução por empresa e mês, combinando os três meses. Consumo usa `{MES_COMPET}`; os demais, `{MES}`.
- **Intervalo:** Encargos e Isenção (ambas as consultas): uma execução por empresa, com `{MES_INICIO}` e `{MES_FIM}`. Não repetir a mesma consulta de intervalo três vezes ou o conjunto será duplicado.
- Para financiamento, o filtro é a **data de entrada da nota**, não a data da compensação. A competência deste modelo representa coorte de notas cadastradas.
- Não copiar a janela ligada a `CURRENT_DATE` dos scripts legados: COVID/Escassez usavam -6 a -1 meses; Isenção, -3 a -1. Os candidatos preservam a parametrização do modelo para permitir conferência histórica.

## Regras que exigem atenção

**MWh:** nos dois encargos, `MWh = ConsumoFaturaOrigem / 1000`, seguindo o original. O alias bruto foi mantido para não alterar medidas existentes silenciosamente. No COVID, `DataDados` registra o momento da extração; na Escassez, lê `FATURAMENTO.DATA_DADOS`. Não tratar os dois campos como o mesmo indicador de atualização.

**Isenção:** `SUM(ICMS)` no SQL legado ocorre após a junção do cabeçalho aos itens; um cabeçalho com vários itens pode ter imposto contado várias vezes. A consulta `13b` seleciona cabeçalhos elegíveis com `EXISTS`, sem multiplicá-los por item/município. Carregá-la como `FatoIsencaoCabecalho`, sem substituir `FatoIsencaoReducao`. Não criar relação direta entre fatos só por número de impressão. Para compartilhar filtros documentais, a chave candidata inclui empresa, competência, impressão e cálculo; validar unicidade e ausência de nulos antes de uma dimensão documental. Valores de cabeçalho não devem ser somados em cada município da redução. Reconciliação com o relatório legado pode revelar a duplicação; diferenças precisam ser explicadas antes de aprovação financeira.

**Injetada:** continuam pré-agregados separadamente os itens financeiros e os itens ZPGAT. `TotalInjetadoOrigem` é consumo ZPGAT, não imposto. `DataEmissao`, `NumeroNF3e` e `ChaveAcesso` continuam nulos de modo explícito: para preenchê-los, é necessária a fonte correspondente. O join de endereço mantém a chave `INSTALACAO` usada no original; se cadastro tiver múltiplas linhas por instalação, não liberar essa ampliação até definir a chave ou vigência correta.

**Financiamento:** os 37 atributos de documento ficam na Nota. Status, contagem de texto de item e valor compensado ficam na Compensação. `ParcelasTextoItemNaoNulo` preserva `COUNT(texto_item)`; isso não prova que corresponda a parcelas distintas. A consulta de compensação é cópia compatível da atual, com risco de multiplicação DOC x SUB ainda pendente. A expansão da Nota pode revelar versões de atributos antes colapsadas pelo `DISTINCT`; não selecionar uma arbitrariamente com `MAX`.

**Consumo:** empresa do Excel deriva de `FOTO_CADASTRO.EMPRESA`; o modelo usa a empresa parametrizada. `EmpresaOrigem` foi acrescentada para permitir a reconciliação. A agregação BC_ICMS e os joins cadastrais originais foram preservados, não homologados por esta revisão.

As variantes RS de Consumo, Encargos, Isenção, Injetada e Financiamento coincidem com as gerais. Retenção AP utiliza a mesma estrutura `SB_FATURAMENTO.{SCHEMA}.BASE_IMPOSTO_RETIDO`. Isso confirma a lógica textual das fontes fornecidas, não que todas as distribuidoras tenham os mesmos dados ou unicidade no banco.

## Validação antes de substituir

1. Usar uma distribuidora e uma competência já conferida; trabalhar em cópia do PBIX.
2. Executar `90_diagnostico_joins.sql` com os parâmetros pela mesma função, sem alteração de dados. Investigar grupos problemáticos e cabeçalhos não encontrados; não forçar deduplicação.
3. Comparar quantidade de linhas e somas por empresa/mês nos candidatos e nas consultas atuais. A ampliação de atributos não deve multiplicar medidas. Em Isenção, conferir o montante de cabeçalho diretamente na fonte, pois o legado pode repeti-lo.
4. Validar tipos no Power Query: IDs/CPF/CNPJ/CEP como texto, datas como data, moeda como decimal fixo conforme precisão da fonte. Nomes SQL preservam a caixa exata com aspas.
5. Aplicar três meses e depois as seis distribuidoras apenas após reconciliar a primeira amostra.

As consultas de diagnóstico verificam condições necessárias, não garantem a integridade financeira de todas as regras. O arquivo `verificacao_estatica.json` registra somente a conferência estrutural local de aliases e cobertura.
