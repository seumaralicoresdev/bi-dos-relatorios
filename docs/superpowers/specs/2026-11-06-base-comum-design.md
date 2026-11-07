# Base comum dos Relatórios Corporativos

Escopo validado na conversa: preparar uma base local compartilhada para Power BI e web, separando Contabilidade e Tributário, preservando aplicativo PySide6 e SQL legados. Fontes são os Excel mensais já gerados. Há dez famílias recebidas em Contabilidade (incluindo TUSD Geradores adicional) e sete em Tributário.

## Comportamento obrigatório

- Identidade da entrega: relatório, competência da remessa, distribuidora e parte. A competência dos registros permanece independente da remessa.
- Distribuidora sem aba/arquivo: `aguardando_arquivo_separado`, valores indisponíveis. Nunca inferir zero ou ausência de movimento.
- Arquivos sem mudança usam cache; cópias idênticas e cópias de conteúdo com outra ordem não duplicam linhas. Partes diferentes com sobreposição parcial causam erro explícito, sem apagar registros silenciosamente.
- Corrigir um arquivo e repetir o processamento substitui sua contribuição; não soma a versão antiga à nova. Cada execução considera o conjunto de arquivos presentes na pasta de entrada ou no manifesto explícito. Manter todas as partes aprovadas nessa entrada.
- Só ativar um novo snapshot após todas as leituras, validações e exportações terminarem. Erro mantém o snapshot anterior utilizável.
- Anos são derivados das competências; não há lista de meses fixa. Testar 2027 e virada de ano.
- Gerar detalhes privados em Parquet, cobertura e agregações JSON por domínio. Agregações não contêm nomes, documentos pessoais, endereços ou identificadores de instalação/contrato/fatura. Ainda são informações corporativas e não são publicadas automaticamente.
- Montantes de nota de financiamento, valores de nota da retenção e consumos de cabeçalho não ganham totais automáticos sem regra de granularidade. Não somar famílias sobrepostas num total financeiro geral.
- A fase não cria PBIX/PBIP, site final ou publicação. Entrega leitor, processador, saídas verificadas e conectores/documentação para os dois formatos.
- Trabalhar no checkout existente; não criar worktree nem modificar o aplicativo original. Nenhum push/publicação nesta fase.

## Arquitetura escolhida

Python local lê XLSX em streaming; cache por hash de arquivo + relatório + remessa + versão do normalizador; Parquet por fonte/aba; consolidação por relatório/remessa/empresa. Um `current.json` aponta atomicamente para o snapshot concluído. O Power BI lê esse ponteiro e os Parquet; aplicações web futuras consomem JSON agregado privado, sujeito à aprovação de acesso/publicação.

Alternativas: consultar Snowflake novamente conserva custos e depende da origem a cada refresh; importar XLSX diretamente nos dois produtos repete normalização e regras de versão. A base comum foi escolhida pelo usuário. O consumo dos arquivos mensais é a opção viável com acesso de leitura e relatórios já aprovados.

## Limites assumidos

Leitura estrutural não é conciliação financeira com razão/Snowflake. Comparações temporais só existem quando há remessas comparáveis. Abas ausentes nos arquivos atuais permanecem pendentes, conforme regra expressamente validada. O manifesto explícito será usado para o lote recebido, sem mover ou publicar planilhas.
