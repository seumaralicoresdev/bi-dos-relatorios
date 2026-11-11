# Revisão das consultas do Power BI — 10/11/2026

Esta revisão compara o contrato de colunas de `relatorios e suas colunas.xlsx`, os campos visíveis no print do modelo e os SQL do pacote original com a automação enviada em `todos scripts da automacao.md` e `Texto colado.txt`.

Os anexos Python foram lidos e suas constantes SQL foram extraídas estaticamente. A automação não foi executada. Não houve conexão ao Snowflake, abertura do PBIX, alteração nos SQL legados ou publicação.

## O que os novos anexos esclareceram

- O Markdown contém 16 consultas. As 15 que já existiam no pacote original coincidem após normalização de formatação; a consulta adicional é TUSD Geradores.
- O texto colado também é o extrator de TUSD Geradores. Seu SQL coincide com o correspondente do Markdown.
- Resumo Faturamento não está nesse novo conjunto. Para ele, a revisão usa o SQL do pacote anterior e identifica essa diferença de fonte.
- Portanto, não há motivo para substituir todas as consultas por estarem em Python. O que deve ser revisto é a adaptação do SQL ao modelo: projeção de colunas, agregações, datas, unidades e relacionamentos.

## Decisões que afetam a correção

**Faturamento:** a tabela atual combina e agrega Clientes Cativos e Clientes Livres. Campos de fatura ou instalação descartados nessa etapa não podem ser recuperados posteriormente. Mantenha a tabela atual para os visuais resumidos; use as consultas detalhadas propostas quando esses campos forem necessários. Não some a fato resumida com suas fatos de origem.

**Modicidade:** os campos visíveis no print são os de Reativos, incompatíveis com o relatório solicitado. Confira o caminho usado no Editor Avançado. O SQL original correto é `modelo/05_fato_modicidade.sql`; o candidato desta revisão também amplia a projeção para o contrato de 14 colunas. Sem o PBIX, não é possível confirmar se houve troca de caminho ou outra transformação no Power Query.

**Retenção:** a linha da planilha repete as 15 colunas de ICMS Injetada. A automação consulta `BASE_IMPOSTO_RETIDO`, e o Excel de outubro tem fornecedor, nota fiscal e retenções de PIS, COFINS, IR e CSLL. A lista de colunas precisa ser confirmada; não se deve usar o SQL de Injetada para preencher essa tabela.

**Nível de detalhe:** acrescentar colunas a uma consulta agregada pode produzir mais linhas. As propostas priorizam fidelidade ao relatório. Não há medição de tempo nem promessa de redução do volume de atualização.

## Período dos três meses

A referência da carga deve continuar sendo `pCompetencia`. Para `202610`, a janela por competência é agosto, setembro e outubro; para `202611`, setembro, outubro e novembro. Calcule o início como o primeiro dia da competência menos dois meses, inclusive na virada do ano.

- Encargos COVID e Escassez do Python usam os seis meses anteriores à data atual. Isso precisa ser substituído pelo intervalo parametrizado no BI. Quando o SQL usa `{MES_INICIO}` e `{MES_FIM}`, execute uma vez por distribuidora, passando início e fim. Não repita a mesma janela três vezes.
- Isenção do Python usa os três meses anteriores à data atual. O resultado só coincide com a janela desejada em determinadas datas; também deve ser parametrizado.
- MMGD do Python consulta o mês informado e os 60 meses anteriores. A consulta consolidada proposta limita a janela; não execute o histórico acumulado uma vez para cada mês.
- TUSD Geradores tem outra regra: o Python transforma a competência informada no mês de referência anterior. Para `202610`, busca referência `202609`; para a empresa interna `D005`, usa o mês calculado a partir de `FIM_CALCULO`. Não há filtro direto por `MES_COMPETENCIA`. O candidato preserva a regra da automação. Exigir exatamente três competências nesse relatório requer confirmar uma mudança de regra de negócio.
- SQL que filtra somente `{MES}` continua mensal. A janela de três meses depende das três chamadas mensais ou de uma adaptação específica do filtro. O quarto argumento da função não transforma automaticamente um SQL mensal em SQL por intervalo.

## Como aplicar com segurança no Desktop

1. Salve uma cópia do PBIX atual.
2. Copie somente os SQL candidatos que deseja homologar para uma pasta nova sob a pasta indicada por `pPastaSQL`. Preserve os arquivos originais.
3. No Power Query, confira o caminho em `fnConsultaSQL` e as etapas posteriores, como seleção, remoção, renomeação e tipagem de colunas. Uma coluna acrescentada ao SQL pode continuar sendo removida por essas etapas.
4. Comece por uma distribuidora e uma competência já conferida. Compare contagem de linhas e totais com o Excel correspondente, respeitando o nível de detalhe e as unidades.
5. Preserve nomes de tabelas e aliases já usados nas medidas quando a semântica for a mesma. Campos novos não exigem renomear todos os campos existentes.
6. Faça as relações das dimensões para as fatos: empresa e data no lado `1`, fatos no lado `*`, filtro em direção única. `DocumentoImpressao` pode se repetir nas fatos; não remova linhas para forçar unicidade nem crie relações automáticas entre fatos por esse campo.
7. Depois da conferência, amplie para seis distribuidoras e a janela acordada. Divergências específicas do RS precisam ser homologadas conforme as notas de cada consulta.

As consultas são candidatas à homologação. A análise estática pode verificar sintaxe e colunas projetadas, mas não confirma permissões, existência e tipos das colunas físicas, unicidade dos joins ou totais reais no Snowflake. A conexão atual do Power BI não precisa ser substituída; esta revisão não reintroduz a opção `Implementation="2.0"`, já rejeitada pelo Desktop usado.
