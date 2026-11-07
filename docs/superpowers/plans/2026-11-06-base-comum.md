# Base comum Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans for core and integration; independent aggregation and connector tasks may be delegated. Steps use checkbox syntax.

**Goal:** Preparar base privada, repetível e extensível a 2027 para os dois domínios, a partir dos Excel existentes.

**Architecture:** XLSX streaming → cache Parquet por conteúdo → consolidação transacional → ponteiro current.json. Agregações e cobertura usam os mesmos dados consolidados; falta de arquivo não vira zero.

**Tech Stack:** Python 3.12, lxml, PyArrow 22, unittest; Power Query M para o conector.

**Spec:** docs/superpowers/specs/2026-11-06-base-comum-design.md

## Global Constraints

- Não alterar /workspace/analise_relatorios/origem nem scripts SQL legados.
- Não publicar dados reais, agregações ou código nesta fase; somente trabalho local.
- Usar checkout e branch atuais, sem worktree.
- Datas de remessa e datas do registro não são intercambiáveis.
- Dados privados ficam fora do repositório, em /workspace/dados_privados.

## Review Focus

- Remessa nova em 2027 e correção de mês anterior não duplicam histórico.
- Arquivo complementar e nomes de abas divididas não trocam a empresa.
- Falha em novo arquivo não destrói snapshot já utilizável.
- Nenhum campo pessoal atravessa a fronteira do exportador JSON.
- Fontes sem aba e arquivos vazios não fabricam movimentos zero.

## Task 1 — Catálogo e leitor

Files: base_comum/catalog.py, base_comum/xlsx.py, tests/test_catalog_reader.py, tests/fixtures.py.
Interfaces: `get_spec(report_id) -> ReportSpec`; `infer_report(filename) -> str`; `read_workbook(path, report_id, delivery_month) -> iterator[(SheetInfo, iterator[dict])]`.

- [x] Escrever fixtures XLSX mínimas com IDs, moeda textual, datas e cabeçalhos repetidos; executar testes antes da implementação.
- [x] Implementar catálogo das 17 famílias, leitura segura, empresa validada e tipos numéricos explícitos.
- [x] Testar 202701, erro de empresa e fórmula sem valor em cache; confirmar IDs preservados e NUMERO renomeado por papel.

## Task 2 — Exportador agregado (independente)

Files: base_comum/aggregate.py, tests/test_aggregate.py.
Interface: `summarize_partition(paths, *, report_id, company, delivery_month, metrics, dimensions) -> dict`, paths Parquet, métricas/dimensões listas permitidas pelo catálogo. Retornar `report_id`, `company`, `delivery_month`, `rows`, `metrics` (valor textual decimal ou null), `breakdowns`. Ausência de observações de uma métrica retorna null; zero observado permanece zero. Nunca exportar linhas individuais.

- [x] Testes falham para soma de métricas, distinção null/zero e exclusão de PII; implementar e passar.
- [x] Validar soma dos agrupamentos contra total e preservação dos sinais.

## Task 3 — Pipeline, cache e atualização

Files: base_comum/pipeline.py, base_comum/__main__.py, tests/test_pipeline.py.
Interface: `build_base(inputs: list[InputFile], output: Path) -> dict`; CLI `python -m base_comum --manifest FILE --output DIR` ou `--input DIR --delivery-month YYYYMM --output DIR`.

- [x] Testes RED: empresa ausente fica null; reexecução não duplica; correção substitui; partes não sobrepõem; falha preserva current.json; outubro e janeiro/2027 coexistem.
- [x] Cache por hash e normalização, consolidação por identidade, ativação atômica e escrita de cobertura + JSON dos domínios.
- [x] Executar testes e lote real; repetir sem alterações e conferir uso de cache e mesmas contagens.

## Task 4 — Conector e operação (independente)

Files: powerbi/fnBaseComum.m, powerbi/FatoFaturamento.m, powerbi/consultas.md, docs/base-comum.md, requirements-base.txt, preparar_base.bat.
Contrato: output/current.json contém snapshot relativo; snapshot contém `parquet/<dominio>/<relatorio>/<remessa>/<empresa>/dados.parquet`, coverage.json e web/contabilidade.json + web/tributario.json.

- [x] Documentar entrada completa/aprovada, correção no mesmo local, partes, dados privados e atualização Desktop/Service/Netlify sem prometer execução externa.
- [x] Conector filtra relatório antes de abrir Parquet e usa datas/IDs de forma explícita. Sem conexão Snowflake ou Implementation=2.0.
- [x] Revisão estática do M; deixar execução Desktop como não verificada.

## Final verification

- [x] Suíte da base e 54 testes do aplicativo original.
- [x] Processar remessa real, cobertura 87 recebidas/15 pendentes e contagens equivalentes ao inventário, sem cópias conhecidas.
- [x] Repetir lote e comprovar que XLSX inalterados não são relidos.
- [x] Revisão independente da implementação; corrigir problemas importantes e repetir verificações afetadas.
