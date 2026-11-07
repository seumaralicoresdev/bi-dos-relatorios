# Execução — 2026-11-06-base-comum.md

Escopo e regra de ausência de aba validados pelo usuário. Branch local feat/base-comum-relatorios; sem worktree ou publicação. Baseline do aplicativo: 54 testes aprovados nesta sessão. Aplicativo e SQL originais não serão alterados.

Interfaces: leitor → pipeline (SheetInfo e linhas normalizadas); pipeline → agregador (Parquet, métricas e dimensões permitidas); pipeline → M (ponteiro relativo e caminhos de dataset).

Task 1: complete — 7 testes do catálogo/leitor RED→GREEN.
Task 2: complete — 8 testes de agregação RED→GREEN; código revisado pelo implementador principal.
Task 3: complete — testes iniciais 8 RED→GREEN; revisão acrescentou 4 reproduções: fonte alterada, argumento explícito de remessa, partes em abas e nome atualizado da fonte. Todos corrigidos e verificados. Lote real e reexecuções concluídos.
Task 4: conector e operação criados; revisão M estática, sem Desktop/Windows.
Ruling: --delivery-month explícito prevalece; sem argumento, inferir por caminho. Motivo: evitar descartar a instrução explícita do operador. Custo se informar mês errado: remessa será atribuída ao mês informado, sem sobrescrever período do registro.
Ruling: nome da fonte faz parte da chave do cache consolidado, não do cache de leitura. Renomear não relê XLSX, mas reconsolida para preservar rastreabilidade. Custo: recomputação daquela partição.
Ruling: Parquet usa float64 para medidas numéricas, conforme contrato; valores textuais com precisão além do tipo exigem revisão antes de uso fiscal. Originais seguem preservados.

Revisão independente: 3 Important e 1 Minor corrigidos. A divergência de rastreabilidade por renomeação foi tratada como importante para este contrato. Nenhum achado desses ficou adiado.

Conferência real dos conectores encontrou um problema adicional em Desconto Tarifário: total auxiliar numérico na célula R1 fora da tabela A:O, variável por distribuidora. Os campos extras estavam vazios em todas as 317.709 linhas. Correção na origem da normalização, específica dessa família: reconhecer a cauda numérica após lacuna e falhar se houver dados nessa área. Duas reproduções RED→GREEN. Versão de normalização por família invalidou apenas o arquivo afetado; não houve perda de colunas da tabela nem mudança dos totais.

Verificação final em 06/11/2026 (horário de São Paulo):

- 29 testes da base e 54 testes do aplicativo original aprovados em execução completa.
- Lote: 29 arquivos de entrada, 17 famílias, 2.968.245 linhas efetivas; uma cópia de conteúdo excluída da consolidação.
- Cobertura: 102 combinações; 87 recebidas e 15 aguardando arquivo separado. Ausências continuam nulas, sem arquivos de movimentos zero.
- Modicidade: 1.266.221 linhas, incluindo PA com 666.926 em duas partes; ICMS Injetada: 915.744 linhas. Ambas com seis distribuidoras.
- 87 Parquet conferidos por contagem e metadados de empresa/remessa; 17 famílias com esquemas consistentes.
- Cinco controles independentes de origem, quatro partições e dez métricas conferidos por centavos e contagem de observações. É amostragem estrutural/financeira contra Excel, não conciliação com razão ou Snowflake.
- Hash e tamanho das 29 fontes conferidos; originais intactos. Pacotes legados conferidos por SHA-256.
- Reexecução final: zero XLSX relidos, 29 caches de leitura e 87 caches de consolidação reutilizados, mesmas linhas e cobertura; 7,054 segundos neste ambiente. Outra medição sem alteração foi 1,445 segundo; não são promessa de desempenho no computador do usuário.
- Todos os JSON agregados após a correção do cabeçalho são idênticos aos anteriores. Evidências com valores financeiros e manifestos permanecem fora do Git.
- M revisado estaticamente e compatível com os esquemas reais. Não executado em Power BI Desktop; atalho Windows não executado neste ambiente Linux.

Fase local encerrada: base, cache, cobertura, agregações, conectores e instruções. Preservar branch e checkout; nenhuma publicação/push. PBIX/PBIP, aplicação web final, autenticação, agendamento externo e implantação permanecem para suas fases próprias.
