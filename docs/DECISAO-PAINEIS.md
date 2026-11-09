# Direção dos painéis — Contabilidade e Tributário

Atualizado em 09/11/2026. Registro único da proposta para a próxima fase. Este documento organiza o trabalho existente; não representa um painel implementado ou publicado.

## Escopo confirmado na conversa

- Duas áreas: Contabilidade e Tributário; seis distribuidoras: MA, PA, PI, AL, AP e RS.
- Atualização mensal e histórico preparado para 2027, sem lista de competências fixa no código.
- O usuário confirmou: totais por distribuidora, mês e categoria no painel; consulta de clientes, instalações e faturas nos relatórios atuais.
- Acesso ao Snowflake somente de leitura. O aplicativo já gera os Excel mensais.
- A ausência de arquivo/aba é pendência, nunca movimento financeiro zero.
- Os originais, o aplicativo, os SQL legados e a base comum existente são preservados.

## Alternativas e recomendação

| Organização | Consequência | Avaliação |
| --- | --- | --- |
| Página por assunto, com as seis distribuidoras e filtros comuns | Permite comparar empresas e manter cada indicador em um lugar | Recomendada, dentro de dois relatórios por área |
| Relatório separado por distribuidora, com todos os assuntos | Multiplica manutenção e dificulta a comparação entre empresas | Usar filtro de distribuidora para atender essa necessidade |
| Somente resumo geral de todos os assuntos | Facilita leitura inicial, mas perde a explicação de variações por assunto | Usar como página inicial de cada área |

Recomendação técnica, ainda sujeita à escolha do usuário: dois arquivos PBIX, um por área. Cada um tem uma página de visão geral e uma página por assunto. Os filtros de distribuidora e competência devem manter a seleção na navegação. Não criar cópias de páginas para cada empresa.

### Contabilidade

Visão geral e páginas para Clientes Cativos, Clientes Livres, Resumo Faturamento/Tributos, Desconto Tarifário, Modicidade Tarifária, Reativos Excedentes, Ultrapassagem de Demanda, MMGD, Saldo Bloqueado e TUSD Geradores.

São dez famílias no catálogo recebido, incluindo TUSD Geradores adicional aos relatórios originais. Proposta de onze páginas, contando a visão geral.

### Tributário

Visão geral e páginas para Isenção ICMS TUSD, Escassez Hídrica, Encargo Covid, Consumo Próprio, Retenção de Tributos, Financiamento de Padrão e ICMS Injetada.

São sete famílias: proposta de oito páginas, contando a visão geral. Consumo Próprio e Financiamento permanecem nesta área conforme a classificação do usuário, mesmo que hoje apareçam em outra pasta do portal.

## Conteúdo das páginas

A visão geral apresenta indicadores separados por assunto e unidade, cobertura das seis distribuidoras, competência selecionada e atualização da base. Não calcula um total monetário somando todos os relatórios: há assuntos sobrepostos e métricas com unidades diferentes.

Cada página de assunto apresenta seus indicadores aprovados, comparação entre distribuidoras, evolução mensal quando existirem períodos comparáveis, categorias relevantes e tabela resumida. Um acesso ao relatório atual atende ao detalhamento de faturas. A passagem automática de filtros ao relatório de destino depende da validação de seus parâmetros e permissões.

As categorias são específicas de cada assunto. Classes, itens, operações e municípios não devem ser equiparados só porque possuem o mesmo texto. O filtro de distribuidora oferece todas ou uma seleção. Ele não é controle de acesso; restrições de acesso, se necessárias, exigem configuração própria.

## Carga recomendada para a primeira versão

Fluxo proposto: aplicativo existente → Excel mensais aprovados → preparador da base comum → tabelas agregadas por assunto → Power BI em modo Importação → portal corporativo.

A origem recomendada para a primeira entrega é a base dos arquivos que já são gerados pelo aplicativo. A navegação e a atualização do Power BI não precisam repetir as consultas Snowflake dessa extração. O aplicativo ainda executa a geração mensal.

O portal apresentado parece ser Power BI Report Server; versão e compatibilidade precisam ser confirmadas com a TI. Validar o formato de entrada, as credenciais de leitura da pasta, o agendamento e o Desktop compatível antes de definir a publicação. A publicação ainda depende de autorização própria.

A conexão Snowflake em Importação permanece uma alternativa de evolução: usar consultas filtradas e agregadas, medir tempo e conferir os resultados antes de substituir a origem da primeira versão. Esta proposta não mantém duas cargas concorrentes para o mesmo indicador. DirectQuery e um novo site Netlify ficam fora do escopo recomendado para esta entrega.

## Como reduzir o trabalho da carga

1. Criar tabelas agregadas próprias para análise. Preservar empresa, período dos registros, remessa quando necessária, categorias que serão filtradas e métricas validadas. Retirar identificadores individuais da camada importada de resumo.
2. Agrupar conjuntamente as dimensões necessárias aos cruzamentos. Os JSON atuais possuem recortes por dimensão independentes; não devem ser tratados como uma tabela que suporta qualquer cruzamento simultâneo.
3. Fazer essa agregação no preparador local antes da importação. Se a origem escolhida passar a ser Snowflake, aplicar filtros e agrupamentos na consulta SQL, conforme a granularidade correta, antes da transferência.
4. Manter fatos por assunto, com dimensões de distribuidora e período quando compatíveis. Evitar relações entre fatos e a união indiscriminada de relatórios com unidades ou regras diferentes.
5. Carregar somente tabelas finais e dimensões necessárias em cada PBIX. Desabilitar a carga de consultas intermediárias evita duplicação no modelo, mas não garante que uma consulta referenciada deixe de executar na origem.
6. Preservar os arquivos aprovados de meses anteriores na entrada. Reutilizar o cache do preparador para arquivos inalterados e substituir a contribuição das versões corrigidas.

O tempo de atualização depende do número de consultas, leitura, agrupamento, transferência e processamento do modelo, não da quantidade de páginas. Dividir em dois PBIX isola as cargas por área; não reduz por si só o trabalho total da extração.

Na função atual, uma chamada atende uma empresa. A combinação de várias empresas, fatos e meses multiplica as consultas. As consultas verificadas de Desconto e Modicidade ainda retornam identificadores de instalação, contrato ou documento. Não há medição do perfil de execução no Snowflake: não atribuir toda a demora apenas ao volume de linhas.

O cache existente foi testado no preparador; isso não comprova o tempo de atualização do Power BI. Não pressupor atualização incremental automática ou suporte a essa funcionalidade na versão do servidor.

## Regras de cálculo que precisam permanecer explícitas

- MMGD e Saldo Bloqueado podem conter histórico ou fotografias sobrepostas. Selecionar a remessa adequada; não somar entregas do mesmo período automaticamente.
- Em Financiamento, definir a granularidade e o período financeiro antes de somar montantes de documentos. A data da remessa não substitui uma data financeira ausente.
- Em Retenção, não somar valores repetidos de notas. Em ICMS Injetada, a coluna RECEITA não é uma medida de ICMS.
- Evitar somar consumos repetidos de cabeçalho. Manter sinais e unidades e validar a precisão dos valores monetários.
- Exibir cobertura parcial: na base de outubro, 87 de 102 combinações foram recebidas e 15 ficaram pendentes. As seis distribuidoras devem aparecer no controle de cobertura, inclusive quando faltarem dados.

## Sequência de execução proposta

1. Fechar este desenho e os indicadores de duas páginas piloto: Desconto Tarifário e Consumo Próprio.
2. Criar e conferir as tabelas agregadas dos pilotos contra os arquivos aprovados, incluindo ausências e sinais. Começar com outubro de 2026; mostrar as seis distribuidoras e suas pendências reais.
3. Montar as páginas piloto no Desktop compatível e medir separadamente preparação, importação e resposta dos visuais. Conferir versão e regras dos relatórios existentes que forem reutilizados.
4. Expandir o padrão validado para os demais assuntos e depois montar as duas visões gerais. A segunda competência permite validar evolução mensal e correção de meses anteriores.
5. Testar atualização no destino corporativo e entregar os PBIX, instruções e critérios de conferência antes de qualquer publicação autorizada.

Ainda não foram criadas nesta revisão as tabelas agregadas destinadas a esses dois modelos, os PBIX ou a rotina agendada no portal. Os componentes existentes estão descritos em [base-comum.md](base-comum.md) e [consultas do Power BI](../powerbi/consultas.md).

Complemento de 09/11/2026: para atender à lentidão da conexão SQL já utilizada, foi preparado um [piloto de Desconto resumido por intervalo](../powerbi/otimizacao/LEIA_ME.md). Ele permite avaliar redução de chamadas e transferência sem substituir as fontes atuais automaticamente. Não é uma mudança da proposta de origem da primeira entrega; a homologação no Snowflake e no Desktop permanece pendente.
