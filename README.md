# bi-dos-relatorios

Arquivos do sistema Relatórios Corporativos e do projeto de integração com Power BI.

O módulo complementar de preparação dos Excel mensais está descrito em [LEIA_PRIMEIRO_BASE_COMUM.md](LEIA_PRIMEIRO_BASE_COMUM.md). Ele produz base privada em Parquet, cobertura e agregações para os dois domínios, sem repetir consultas Snowflake na navegação dos painéis.

## Downloads

- [Baixar o aplicativo Relatórios Corporativos — código-fonte ZIP](https://github.com/seumaralicoresdev/bi-dos-relatorios/raw/refs/heads/main/downloads/Relatorios_Corporativos.zip)
- [Baixar o projeto Power BI — SQL, DAX e documentação ZIP](https://github.com/seumaralicoresdev/bi-dos-relatorios/raw/refs/heads/main/downloads/Projeto_PowerBI.zip)

Os arquivos também estão na pasta [downloads](downloads). Ao abrir um ZIP no GitHub, use **Download raw file** (ícone de seta para baixo).

## Revisão e propostas visuais do Power BI

- [Auditoria das colunas e SQL candidatos](powerbi/revisao_colunas_20261110/LEIA_ME.md)
- [Temas de cor e fundos](powerbi/temas/LEIA-ME.md)
- [Baixar temas JSON e imagens de fundo](powerbi/Temas_e_Fundos_PowerBI.zip)
- [Baixar as maquetes SVG](powerbi/Propostas_SVG_Painel_PowerBI.zip)

Os SQL dessa auditoria são candidatos e ainda precisam ser homologados no Power BI Desktop e no Snowflake antes do uso operacional.

O aplicativo é um projeto Python/PySide6 para Windows. Extraia o ZIP e siga o `README.md` e `docs/operator-guide.md` contidos nele. O executável Windows deve ser gerado com `build_windows.bat` e `RelatoriosDesktop.spec`; ele não está incluído neste download.

O pacote Power BI contém as consultas, medidas DAX, relacionamentos, desenho das páginas e instruções de implantação. **Ainda não contém um arquivo `.pbix` ou `.pbip`.** A conexão ao Snowflake e a validação no Power BI Desktop permanecem necessárias.

Os ZIPs preservam os arquivos já preparados, sem alterações no código ou nos scripts SQL legados. As somas de verificação estão em [downloads/SHA256SUMS.txt](downloads/SHA256SUMS.txt).
