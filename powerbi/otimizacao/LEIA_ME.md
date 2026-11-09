# Piloto para reduzir a carga do Desconto Tarifário

Este ajuste atende à consulta Snowflake que está lenta no Power BI. É uma cópia de trabalho: não substitui o SQL legado nem muda automaticamente o arquivo PBIX do usuário. A fonte da primeira versão dos dois painéis continua sendo a proposta registrada em [DECISAO-PAINEIS.md](../../docs/DECISAO-PAINEIS.md).

## O que muda

- A consulta retorna totais por empresa, competência, item, operação, categoria tarifária e subclasse, sem identificadores de fatura, instalação ou contrato no resultado final.
- Um intervalo inteiro de competências é consultado por empresa. Não há um laço de consultas para cada mês.
- Exemplo: seis empresas e dez meses deixam de exigir 60 chamadas lógicas à função mensal e passam a seis chamadas à função por intervalo. Pré-visualizações e reavaliações do Power Query ainda podem executar consultas adicionais.
- A soma acontece no Snowflake antes da transferência. Acrescentar apenas `Table.Group` depois de baixar o detalhe não garante esse benefício.

Isso reduz solicitações e linhas transferidas; o banco ainda precisa ler e calcular o período pedido. Menos chamadas não significa redução proporcional de créditos ou tempo. Não foram medidos tempo nem custo no Snowflake.

## Evidência disponível

No lote local de outubro de 2026, as cinco distribuidoras recebidas em Desconto somam 317.709 linhas. Agrupar pelas dimensões deste piloto produziu 536 grupos, preservando a soma e os sinais: redução de 99,83% nas linhas desse conjunto. Essa conferência foi feita sobre os Parquet normalizados dos Excel, não sobre o resultado ao vivo do novo SQL. Ela não confirma a distribuidora ausente nem substitui a homologação contra o banco.

Sete testes executam a lógica relacional do SQL em SQLite, adaptando somente os nomes de catálogo e funções de conversão. Cobrem agrupamento, sinais, exclusões, nulos, duplicações, virada de ano e isolamento entre meses. Snowflake e o código M ainda precisam ser executados no ambiente corporativo.

## Aplicar em um arquivo de teste no Desktop

1. Abra um PBIX novo na mesma versão do Desktop utilizada para o servidor corporativo. Isso isola a medição das outras fatos pesadas do arquivo atual.
2. Copie [02_fato_desconto_resumo.sql](02_fato_desconto_resumo.sql) para a subpasta `modelo` da pasta apontada pelo parâmetro `pPastaSQL`. É um arquivo novo; mantenha `02_fato_desconto.sql` original.
3. Crie parâmetros de texto `pServidorSnowflake`, `pWarehouse` e `pPastaSQL` com os mesmos valores do arquivo atual. Crie também `pMesInicio` e `pCompetencia`, inicialmente ambos `202610`. Use as credenciais pelo conector; não escreva senhas no código.
4. Crie uma consulta em branco, cole [fnConsultaSQLPeriodo.m](fnConsultaSQLPeriodo.m) no Editor Avançado e dê o nome `fnConsultaSQLPeriodo`. Ela não deve ser carregada como tabela. Essa nova função exige um SQL preparado para intervalo; não funciona como substituição automática da função mensal em todos os relatórios.
5. Crie outra consulta em branco, cole [FatoDescontoResumo.m](FatoDescontoResumo.m) e nomeie `FatoDescontoResumo`. Para a primeira conferência, ajuste a lista para `Empresas = {"EQTL_MA"}`.
6. Use **Fechar e Aplicar** para medir a importação completa; o tempo da prévia pode corresponder apenas a uma amostra. Compare `SUM(ValorDescontoAssinado)` por competência e categoria com o relatório aprovado do mesmo período e distribuidora.
7. Conferidos os valores, restaure a lista das seis empresas. Se alguma não retornar dados ou apresentar erro, mantenha a pendência explícita. Depois amplie `pMesInicio`, por exemplo para `202601`, mantendo `pCompetencia` como o último mês necessário.

As medidas do piloto podem ser:

```dax
Valor Desconto = SUM(FatoDescontoResumo[ValorDescontoAssinado])
Linhas da Origem = SUM(FatoDescontoResumo[LinhasOrigem])
```

`LinhasOrigem` conta os registros após o agrupamento intermediário do SQL legado. Não é contagem distinta de clientes, faturas ou instalações. Não há necessidade de usar `ABS` nem arredondar previamente os valores monetários; homologar precisão e tolerância com a área responsável.

## Comparar e migrar

Compare a consulta original e a resumida para as mesmas empresas, meses, warehouse e condições de cache. Registre tempo, linhas importadas e totais. Se houver acesso ao histórico/perfil de consultas do Snowflake, diferencie tempo em fila, leitura, execução e transferência; a fila do warehouse exige avaliação da equipe responsável.

Após homologação, substitua a fonte da fato correspondente no arquivo de trabalho, revisando nomes de colunas, relacionamentos e medidas. Evite deixar as duas consultas finais atualizando os mesmos dados. Desabilitar a carga de uma consulta intermediária não impede sua execução quando outra consulta a referencia.

Não aplique a transformação de intervalo cegamente aos demais SQL. Aqui foi necessário incluir competência na partição da função de janela; sem isso, o mesmo documento presente em meses diferentes poderia mudar o valor selecionado de operação e alterar as exclusões. As regras mensais de MMGD, Saldo Bloqueado e documentos de Financiamento também exigem tratamento próprio.

No modo Importação, esse piloto ainda consulta o intervalo inteiro em cada atualização. Para evitar releitura de meses encerrados, é necessário persistir resultados ou validar uma estratégia de atualização compatível com o destino. A base comum dos Excel já fornece cache para a preparação local; suporte a atualização incremental no servidor não foi presumido.

Os arquivos deste piloto são somente código e instruções. Não contêm dados reais e não representam publicação no portal.
