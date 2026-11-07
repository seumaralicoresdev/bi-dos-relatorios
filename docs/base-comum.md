# Preparar a base comum

A base comum lê os Excel mensais já aprovados e cria uma saída local para Power BI e aplicações web futuras. O aplicativo PySide6 e os SQL legados continuam independentes. As 17 famílias são dez de Contabilidade, incluindo o adicional TUSD Geradores, e sete de Tributário.

## Requisitos e pastas

Use Python 3.12, com o launcher `py` no Windows, e instale manualmente as dependências em [requirements-base.txt](../requirements-base.txt), na pasta deste projeto:

```bat
py -3 -m pip install -r requirements-base.txt
```

O preparador não instala pacotes automaticamente. Guarde arquivos e saídas fora do repositório, por exemplo:

```text
C:\RelatoriosCorporativos\
  entrada\
    202610\
    202701\
  manifestos\
  saidas\
```

Cada pasta de remessa deve conter o conjunto completo de arquivos e partes aprovados daquela entrega. A remessa é o mês da entrega, não necessariamente o mês dos registros. Anos e meses são derivados dos dados; janeiro de 2027 não exige uma lista de meses nova no código.

Não adicione Excel, Parquet, cache, cobertura nem JSON reais ao Git. Inclusive agregações sem dados pessoais continuam sendo informações corporativas privadas. Esta etapa não publica em GitHub, Power BI Service, Netlify ou outro serviço e não cria PBIX/PBIP.

## Executar as remessas selecionadas

Abra o terminal na pasta do projeto. `--input` busca os Excel recursivamente. Com as pastas de remessa mostradas acima, processe o histórico completo com:

```bat
python -m base_comum --input "C:\RelatoriosCorporativos\entrada" --output "C:\RelatoriosCorporativos\saidas"
```

A remessa é inferida do nome/caminho de cada arquivo quando `--delivery-month` não é informado. Assim, `entrada\202610` e `entrada\202701` podem entrar na mesma execução, reutilizando o cache dos arquivos inalterados. Mantenha as pastas anteriores na entrada para conservar seu histórico no snapshot novo. No Windows, `py -3` pode substituir `python` nesse comando.

Para fixar todos os arquivos selecionados em uma única remessa, informe `--delivery-month`:

```bat
py -3 -m base_comum --input "C:\RelatoriosCorporativos\entrada\202610" --delivery-month 202610 --output "C:\RelatoriosCorporativos\saidas"
```

Em modo `--input`, a remessa explícita prevalece sobre o mês identificado no nome/caminho. Use esse modo para um conjunto de uma remessa; para histórico com várias remessas, use a entrada recursiva sem essa flag ou um manifesto com os meses explícitos. Uma seleção isolada de outubro recompõe um snapshot somente com os arquivos selecionados, sem incorporar outras remessas automaticamente.

O atalho recebe exatamente três argumentos, na ordem pasta de entrada, remessa e pasta de saída, e fixa esse conjunto em uma única remessa:

```bat
preparar_base.bat "C:\RelatoriosCorporativos\entrada\202610" 202610 "C:\RelatoriosCorporativos\saidas"
```

O `.bat` muda para a pasta do projeto, chama `py -3 -m base_comum` e devolve o código de saída do processador. Se a entrada contém somente o mês novo, essa execução não acrescenta os meses antigos ao snapshot; para manter o histórico, use o comando recursivo sem a flag de remessa ou o manifesto completo. Código diferente de zero indica falha; confira a mensagem antes de atualizar o Power BI.

## Manifesto e histórico

Cada execução recompõe o snapshot a partir do conjunto de entradas selecionado. Ela não incorpora implicitamente arquivos de snapshots antigos. Para conservar histórico, mantenha todas as pastas aprovadas na entrada recursiva ou relacione todas as entradas aprovadas no mesmo manifesto. O manifesto também permite declarar o total de partes esperado:

```bat
py -3 -m base_comum --manifest "C:\RelatoriosCorporativos\manifestos\historico.json" --output "C:\RelatoriosCorporativos\saidas"
```

Formato do manifesto:

```json
{
  "inputs": [
    {
      "path": "C:/RelatoriosCorporativos/entrada/202610/clientes_cativos_parte1.xlsx",
      "report_id": "clientes_cativos",
      "delivery_month": "202610"
    },
    {
      "path": "C:/RelatoriosCorporativos/entrada/202701/clientes_cativos_parte1.xlsx",
      "report_id": "clientes_cativos",
      "delivery_month": "202701"
    }
  ]
}
```

O exemplo mostra o formato; complete o manifesto com todas as famílias e partes aprovadas. Caminhos relativos são resolvidos a partir da pasta do manifesto; use caminhos absolutos para tornar a seleção explícita. `report_id` pode ser omitido quando a família for reconhecível no nome. No manifesto, `delivery_month` explícito em cada entrada é preservado. Se esse campo for omitido, o processador usa `--delivery-month`, quando informado; sem a flag, infere a remessa do nome/caminho. Sem identificação suficiente, informe o campo explicitamente.

`part_number` e `parts_total` são campos opcionais do manifesto. Para uma entrega dividida, informe a numeração de cada parte e o mesmo total esperado em todas as entradas correspondentes. Por exemplo, Modicidade PA com duas partes:

```json
{
  "inputs": [
    {
      "path": "C:/RelatoriosCorporativos/entrada/202610/Modicidade_PA_parte1.xlsx",
      "report_id": "modicidade_tarifaria",
      "delivery_month": "202610",
      "part_number": 1,
      "parts_total": 2
    },
    {
      "path": "C:/RelatoriosCorporativos/entrada/202610/Modicidade_PA_parte2.xlsx",
      "report_id": "modicidade_tarifaria",
      "delivery_month": "202610",
      "part_number": 2,
      "parts_total": 2
    }
  ]
}
```

Use os caminhos dos arquivos efetivamente aprovados e mantenha também as demais entradas do histórico no manifesto. Partes sem total declarado ficam em `partes_recebidas_cobertura_nao_confirmada`. Com `parts_total = N` e o conjunto completo de partes `1..N`, a cobertura pode ser registrada como `arquivo_recebido`. Receber uma parte não confirma que a entrega inteira chegou.

## Correções, partes e cache

Para corrigir uma entrega, substitua o arquivo aprovado no mesmo caminho, mantendo as demais partes aprovadas, e repita o mesmo comando ou manifesto. Não deixe uma versão antiga ao lado da corrigida com outro nome. O snapshot novo substitui a contribuição anterior; não soma as duas versões.

Partes complementares são entradas distintas e devem permanecer todas no conjunto processado. Cópias idênticas e cópias de conteúdo com outra ordenação não duplicam linhas. Sobreposição parcial entre partes distintas interrompe o processamento: revise a entrega em vez de remover linhas silenciosamente. Um arquivo vazio não comprova ausência de movimento.

O cache usa hash do conteúdo, relatório, remessa e versão do normalizador. Arquivos inalterados reutilizam o Parquet normalizado. Renomear um arquivo sem alterar conteúdo não transforma a cópia em uma parte nova; alterar o conteúdo invalida o cache correspondente. O cache acelera a leitura e não substitui a manutenção do conjunto completo de entradas.

## Saídas e ausência de empresa

Após leitura, validação e exportação completas, `saidas/current.json` aponta para o snapshot concluído:

```json
{"schema_version": 1, "snapshot": "snapshots/<id>"}
```

Campos adicionais de controle podem existir. Dentro desse snapshot:

```text
parquet/<dominio>/<relatorio>/<competencia_remessa>/<empresa>/dados.parquet
coverage.json
web/contabilidade.json
web/tributario.json
```

Os Parquet são detalhados e privados. Preservam as colunas de origem e os metadados de empresa, remessa, período real, arquivo, aba e linha; consumo próprio distingue `NUMERO_FATURA` de `NUMERO_ENDERECO`. O Power BI consulta apenas os Parquet do relatório solicitado, conforme [configuração das consultas](../powerbi/consultas.md).

Em Desconto Tarifário, o layout pode conter um total numérico auxiliar à direita do cabeçalho, separado da tabela por colunas vazias. Esse total não é uma coluna de registros. O leitor reconhece essa cauda numérica e exige que a área correspondente esteja vazia em todas as linhas de dados; se houver conteúdo, interrompe a leitura para revisão do layout.

`coverage.json` identifica o que foi recebido por empresa, relatório e remessa. Distribuidora sem arquivo/aba fica em `aguardando_arquivo_separado`, com valor indisponível. Partes recebidas sem confirmação do total ficam em `partes_recebidas_cobertura_nao_confirmada`; confira a declaração de partes no manifesto. Nunca presumir zero, ausência de movimento ou completude financeira. Período dos dados e competência da remessa são eixos diferentes e devem permanecer visíveis na análise.

Os JSON web contêm apenas dimensões e métricas agregadas permitidas, sem nomes, documentos pessoais, endereços ou identificadores individuais de instalação, contrato e fatura. Ainda exigem controle de acesso corporativo. Nem toda coluna numérica admite soma: montantes documentais, valores de nota em retenções e consumos de cabeçalho precisam de regra de granularidade aprovada.

Se qualquer leitura, validação ou exportação falhar, `current.json` continua apontando para o snapshot anterior. Confira a mensagem e a data do lote antes de interpretar os resultados. Não edite um snapshot manualmente nem remova pastas que consumidores ainda possam estar usando.

## Conferência operacional

Antes do uso, confirme as remessas selecionadas, a cobertura esperada, as contagens por família/empresa e os totais permitidos. Reexecute sem alterações para conferir cache e estabilidade; uma execução com arquivos corrigidos deve substituir somente a contribuição prevista. A leitura estrutural dos Excel não constitui conciliação com razão ou Snowflake.

A atualização no Desktop exige o preparador executado e as consultas homologadas. O Service requer gateway e agendamento configurados separadamente. Uma aplicação web precisa de implementação própria e aprovação de acesso/publicação; Netlify não processa estes Excel nem lê a pasta Windows automaticamente. Nenhuma dessas execuções externas é realizada por esta entrega.

## Interpretação das medidas

As medidas numéricas do Parquet usam `float64`, compatível com números decimais do Excel e do Power BI. Para uso fiscal exato, homologar precisão e tolerância com a área responsável; não tratar o arquivo como substituto do razão ou de um sistema fiscal. Os originais continuam sendo a referência preservada.

MMGD já contém uma janela histórica e Saldo Bloqueado contém fotografias. Selecionar a remessa apropriada antes de totalizar; não somar remessas sobrepostas. Em Modicidade, referência da entrega e mês de lançamento são eixos distintos. As classes de Cativos e Livres não foram equiparadas por texto.

O exportador agregado usa apenas as métricas permitidas pelo catálogo. Em Retenção, soma os campos dos tributos, sem totalizar automaticamente o valor das notas. Em Financiamento, exporta contagens e categorias, deixando os montantes para uma regra de grão aprovada. Em ICMS Injetada, `RECEITA` continua sendo o valor dos itens, não uma coluna de ICMS. Consumos de cabeçalho não são somados automaticamente como energia.
