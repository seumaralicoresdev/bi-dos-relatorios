# Base comum — Relatórios Corporativos

Este módulo complementar prepara os Excel mensais para Power BI e aplicações web. Não substitui o aplicativo gerador nem altera seus SQL.

1. Instale Python 3.12 e as dependências: `py -3 -m pip install -r requirements-base.txt`.
2. Organize os Excel aprovados fora deste repositório, em subpastas de competência, como `C:\RelatoriosCorporativos\entrada\202610` e `...\202701`.
3. Execute na pasta deste módulo: `py -3 -m base_comum --input "C:\RelatoriosCorporativos\entrada" --output "C:\RelatoriosCorporativos\saidas"`.
4. Leia o resultado no terminal e confira `coverage.json` do snapshot indicado por `saidas\current.json`.
5. No Power BI, use os arquivos em `powerbi` e o parâmetro `pBasePasta`, seguindo [o guia](powerbi/consultas.md).

Arquivos sem alteração reutilizam o cache. Correções substituem a contribuição da versão anterior quando o conjunto de entrada mantém apenas os arquivos aprovados. Todas as partes de uma entrega devem permanecer na entrada; declare `parts_total` no manifesto para confirmar completude das partes.

Ausência de aba/arquivo permanece `aguardando_arquivo_separado`, sem valor financeiro zero presumido. O histórico do snapshot é o conjunto selecionado na execução: para conservar meses anteriores, mantenha-os na árvore de entrada ou no manifesto.

Consulte [a operação detalhada](docs/base-comum.md). Os JSON de Contabilidade e Tributário ficam em `web/` dentro do snapshot: são dados agregados privados, não sites publicados. Nenhuma saída real deve ser enviada ao repositório público. A entrega não contém PBIX/PBIP nem um painel web final.
