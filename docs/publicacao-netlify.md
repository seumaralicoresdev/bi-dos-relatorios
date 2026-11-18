# Índice do projeto no Netlify

A pasta `site` contém a página inicial e os quatro pacotes oferecidos para
download. A página é estática: não contém planilhas mensais, credenciais,
conexão com o Snowflake nem um arquivo PBIX. Os botões de Contabilidade e
Tributário abrem os diretórios corporativos informados para o projeto; o
acesso a eles depende das permissões e da rede da organização.

## Publicação manual

1. Se receber `Pagina_Relatorios_Netlify.zip`, extraia-o no computador.
   A pasta extraída deve conter `index.html` e a pasta `arquivos` lado a lado.
   Se estiver usando o repositório, use a pasta `site` diretamente.
2. Entre na sua conta em <https://app.netlify.com/drop>.
3. Arraste a pasta que contém `index.html` e `arquivos` para a área de
   publicação manual. O Netlify criará um endereço do site; aguarde a conclusão
   e abra esse endereço.
4. Confira os dois links do portal e os downloads. Para alterar o site depois,
   envie novamente a pasta atualizada na página de deploy do site.

## Publicação a partir do GitHub

1. Envie as alterações desta pasta e de `netlify.toml` ao GitHub.
2. No Netlify, escolha adicionar um projeto a partir de um repositório Git e
   selecione `seumaralicoresdev/bi-dos-relatorios` e a branch que contém a
   página.
3. A configuração já informa `site` como diretório de publicação. Deixe o
   comando de build vazio e publique seguindo as telas do Netlify.
4. Confirme que a branch selecionada é a desejada: alterações enviadas a ela
   podem gerar novas publicações automáticas, conforme a configuração do site.

## Manutenção

- `site/index.html` contém a estrutura, a aparência e o filtro de assuntos.
- `site/arquivos` contém cópias dos pacotes distribuídos no índice. Ao atualizar
  um pacote no projeto, substitua também a cópia correspondente nessa pasta.
- Os relatórios, dados e permissões são mantidos nos sistemas de origem. Este
  índice não atualiza relatórios nem executa o aplicativo desktop.
- Antes de publicar uma versão, confirme que somente materiais aprovados para
  divulgação estão em `site`; não coloque Excel, saídas da base privada ou
  credenciais nessa pasta.
