@echo off
setlocal EnableExtensions DisableDelayedExpansion
if "%~1"=="" goto :uso
if "%~2"=="" goto :uso
if "%~3"=="" goto :uso
if not "%~4"=="" goto :uso
set "BASE_INPUT_FOLDER=%~1"
set "BASE_DELIVERY_MONTH=%~2"
set "BASE_OUTPUT_FOLDER=%~3"
cd /d "%~dp0"
if errorlevel 1 exit /b %errorlevel%
where py >nul 2>&1
if errorlevel 1 goto :sem_python
py -3 -m base_comum --input "%BASE_INPUT_FOLDER%" --delivery-month "%BASE_DELIVERY_MONTH%" --output "%BASE_OUTPUT_FOLDER%"
set "BASE_EXIT_CODE=%errorlevel%"
if not "%BASE_EXIT_CODE%"=="0" (
    echo.
    echo Falha no processamento. Confira a mensagem acima.
    echo Requisitos: Python 3.12 e dependencias de requirements-base.txt.
    echo Instalacao manual: py -3 -m pip install -r requirements-base.txt
)
exit /b %BASE_EXIT_CODE%

:sem_python
echo O launcher py nao foi encontrado. Instale Python 3.12 com o launcher do Windows.
echo Depois instale manualmente: py -3 -m pip install -r requirements-base.txt
exit /b 1

:uso
echo Uso: preparar_base.bat "pastaEntrada" YYYYMM "pastaSaida"
echo Exemplo: preparar_base.bat "C:\RelatoriosCorporativos\entrada\202610" 202610 "C:\RelatoriosCorporativos\saidas"
echo Requisitos: Python 3.12 com launcher py e dependencias de requirements-base.txt.
echo Instalacao manual: py -3 -m pip install -r requirements-base.txt
echo O preparador nao instala pacotes automaticamente.
exit /b 2
