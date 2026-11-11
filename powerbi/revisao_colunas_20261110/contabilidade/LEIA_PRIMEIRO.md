# Revisão de colunas da Contabilidade — 10/11/2026

Os dez arquivos SQL são **candidatos para revisão**. Nenhum foi executado no Snowflake, carregado no PBIX ou publicado. A comparação cobre as 141 posições de coluna exigidas na aba CONTABILIDADE, o print do modelo e os SQL legados disponíveis. Campos ocultos e outras tabelas do PBIX não foram inspecionados.

`audit.json` registra cada coluna exigida, seu alias visível, o alias proposto, diferenças semânticas, fonte, modo de carga e ressalvas. `verificacao_estatica.json` comprova apenas projeção, aliases únicos, placeholders compatíveis e ausência de comandos de escrita; não comprova compilação no Snowflake.

## Aplicação proposta

| Consulta no BI | Arquivo candidato | Ação |
|---|---|---|
| FatoClientesCativos | 01_clientes_cativos_completo.sql | Criar tabela separada com o grão do relatório original; manter FatoFaturamento. |
| FatoClientesLivres | 02_clientes_livres_completo.sql | Criar tabela separada para recuperar instalação, documento, fatura e conta; manter FatoFaturamento. |
| FatoDesconto | 03_desconto_completo.sql | Ampliar a projeção em cinco colunas. |
| FatoModicidade | 04_modicidade_completo.sql | Primeiro corrigir o caminho/código da consulta: o print mostra colunas incompatíveis com Modicidade. |
| FatoReativos | 05_reativos_completo.sql | Ampliar a projeção em quatro colunas. |
| FatoUltrapassagem | 06_ultrapassagem_completo.sql | Ampliar a projeção em três colunas. |
| FatoMMGDConsolidado | 07_mmgd_consolidado_3meses.sql | Criar consolidado por empresa e mês de crédito; uma chamada por distribuidora. |
| FatoResumoFaturamento | 08_resumo_faturamento_completo.sql | Tabela não identificada no print; conferir schema antes da carga. |
| FatoSaldoBloqueado | 09_saldo_bloqueado_equivalente_ao_excel.sql | Opcional: não faltam colunas. Usar apenas se a conciliação exigir o TRUNC do relatório Excel. |
| FatoTUSDGeradores | 10_tusd_geradores_completo.sql | Tabela não identificada no print; fonte agora conhecida, mas regra temporal exige decisão. |

Os nomes novos preservam os aliases já usados no modelo quando a equivalência é comprovada. Os nomes legados do Excel não precisam ser os nomes físicos no BI. Datas de mês usam o primeiro dia do mês; exibir `AAAA-MM` no relatório. Valores não recebem `ABS`, exclusão de duplicidades ou arredondamento automático. Identificadores são texto, preservando zeros existentes na origem.

## Período e janela de três meses

- Cativos, Livres, Desconto, Reativos, Ultrapassagem e Resumo preservam o filtro mensal de competência. Para agosto/setembro/outubro, executar cada SQL com `202608`, `202609` e `202610`, separadamente. Esta revisão de colunas não reduz o custo dessas consultas.
- Modicidade preserva o filtro mensal de `REFERENCIA`, representado como `DataCompetencia` no modelo original. Confirmar que essa referência é a competência usada na conciliação.
- Saldo Bloqueado é uma fotografia por mês. Pode ser carregado para três datas de corte, mas os saldos dos três meses não devem ser somados como movimento.
- MMGD é uma exceção: o candidato já filtra `MES-2` até `MES`, inclusive. Com `pCompetencia=202610`, retorna os meses de crédito agosto/setembro/outubro em **uma chamada por empresa**. Repetir a consulta para cada um dos três meses duplicaria períodos. A mudança de 61 meses históricos para três está explicitamente documentada no SQL.
- TUSD preserva `previous_competencia` da automação. `pCompetencia=202610` seleciona referência `202609`; para `D005`, seleciona `CONTA_MES=202609`, calculado a partir de `FIM_CALCULO`. Não filtra a coluna de competência de saída. Definir se o painel seguirá referência do relatório ou competência contábil antes de montar a janela. O candidato não troca silenciosamente a regra de origem.

## Fonte e diferenças do RS

Os novos SQL da automação coincidem com os originais para as famílias já conhecidas. A fonte de TUSD foi acrescentada agora. Resumo permanece baseado no SQL antigo, que usa `SELECT A.*`, combinado com as colunas exigidas no Excel; o candidato precisa da confirmação de `CLIENTE_LIVRE` e `DATA_DADOS` no schema atual.

Há versões antigas específicas do RS que divergem do bundle recém-enviado: Cativos exclui um documento específico; Desconto inclui `ZBIL`; Reativos muda `SUM` de impostos para `MAX` e exclui o mesmo documento; MMGD usa a tabela RAW de créditos, `ALLOC_DATE` e `QUANT`, em lugar da base preparada. Os candidatos seguem a automação atual. Essas regras antigas não foram reaplicadas. Conciliar RS separadamente e confirmar a regra vigente, especialmente no MMGD. O mapeamento RAW informado no bundle para RS é `CCS_RS`, não `EQTL_RS`.

## Validação antes de substituir uma consulta

1. Duplicar a consulta existente no Power Query e testar o candidato em uma empresa e uma competência.
2. Conferir nomes, tipos e datas inválidas/nulas; confirmar os campos mantidos como texto.
3. Conciliar quantidade de linhas e somas por empresa/mês com a saída do mesmo SQL original. Para as tabelas completas, não usar a contagem da FatoFaturamento agregada como referência de quantidade de linhas.
4. Conferir RS e os casos de saldo truncado, grupos zerados de MMGD e referência de TUSD.
5. Manter fatos no lado muitos dos relacionamentos com dimensões. DocumentoImpressao pode repetir por item/documento de cálculo; não configurar como chave única nem deduplicar para eliminar o erro.
6. Só depois ampliar o conjunto de empresas/meses e trocar as consultas usadas pelos visuais. Medidas de Modicidade devem apontar a `ValorModicidadeAssinado`; não tratar `ValorFaturado` do print como equivalente sem conferir a consulta.

`gerar_candidatos.py` é um gerador local para rastreabilidade: lê o JSON de evidências e os textos SQL preparados nesta revisão. Não é parte da atualização mensal do BI, não contém credenciais e não executa o Python dos anexos.
