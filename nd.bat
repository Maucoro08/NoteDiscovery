@echo off
setlocal

:: ============================================================
:: nd.bat  -  NoteDiscovery dev helper
::
::   nd init    Crea el entorno virtual, instala/actualiza
::              dependencias y lo desactiva al terminar.
::
::   nd start   Activa el entorno (si no lo está) y arranca
::              el servidor con run.py
::
::   nd stop    Detiene el servidor si está corriendo y
::              desactiva el entorno virtual.
:: ============================================================

set "VENV_DIR=%~dp0.venv"
set "PID_FILE=%~dp0.nd_server.pid"

if "%~1"=="" goto :usage
if /i "%~1"=="init"  goto :cmd_init
if /i "%~1"=="start" goto :cmd_start
if /i "%~1"=="stop"  goto :cmd_stop
goto :usage

:: ------------------------------------------------------------
:cmd_init
echo [nd] Inicializando entorno virtual en .venv ...

if not exist "%VENV_DIR%\Scripts\activate.bat" (
    python -m venv "%VENV_DIR%"
    if errorlevel 1 (
        echo [nd] ERROR: no se pudo crear el entorno virtual.
        echo        Asegurate de tener Python 3.10+ en el PATH.
        exit /b 1
    )
    echo [nd] Entorno virtual creado.
) else (
    echo [nd] Entorno virtual ya existe, se reutiliza.
)

call "%VENV_DIR%\Scripts\activate.bat"

echo [nd] Actualizando pip ...
python -m pip install --upgrade pip --quiet

echo [nd] Instalando / actualizando dependencias ...
pip install -r "%~dp0requirements.txt" --upgrade --quiet

echo [nd] Desactivando entorno virtual ...
call deactivate 2>nul

echo [nd] Listo. Usa  nd start  para arrancar el servidor.
exit /b 0

:: ------------------------------------------------------------
:cmd_start
:: Activar entorno si no está activo (VIRTUAL_ENV no definida)
if not defined VIRTUAL_ENV (
    if not exist "%VENV_DIR%\Scripts\activate.bat" (
        echo [nd] El entorno virtual no existe. Ejecuta primero:  nd init
        exit /b 1
    )
    call "%VENV_DIR%\Scripts\activate.bat"
    echo [nd] Entorno virtual activado.
) else (
    echo [nd] Entorno virtual ya activo: %VIRTUAL_ENV%
)

:: Guardar PID del proceso padre de esta sesión cmd para poder
:: encontrar el proceso uvicorn hijo al detenerlo.
echo [nd] Arrancando servidor (Ctrl+C para detener) ...
echo %~dp0 > "%PID_FILE%"

python "%~dp0run.py"

:: Cuando run.py termina (Ctrl+C o error) limpiamos el PID
if exist "%PID_FILE%" del "%PID_FILE%"

echo [nd] Servidor detenido.
exit /b 0

:: ------------------------------------------------------------
:cmd_stop
echo [nd] Buscando proceso uvicorn ...

:: Buscar procesos Python cuya línea de comandos contenga "uvicorn"
:: taskkill /F mata todos los que coincidan.
tasklist /FI "IMAGENAME eq python.exe" /FO CSV 2>nul | find /I "python.exe" >nul
if errorlevel 1 (
    echo [nd] No hay procesos Python corriendo.
    goto :stop_deactivate
)

:: Intentar matar solo los que tienen "uvicorn" en la línea de comando
wmic process where "name='python.exe' AND commandline like '%%uvicorn%%'" get processid 2>nul | findstr /r "[0-9]" >nul
if errorlevel 1 (
    echo [nd] No se encontro ningun proceso uvicorn activo.
    goto :stop_deactivate
)

echo [nd] Deteniendo proceso uvicorn ...
wmic process where "name='python.exe' AND commandline like '%%uvicorn%%'" call terminate >nul 2>&1
echo [nd] Proceso detenido.

:stop_deactivate
if exist "%PID_FILE%" del "%PID_FILE%"

if defined VIRTUAL_ENV (
    echo [nd] Desactivando entorno virtual ...
    call deactivate 2>nul
    echo [nd] Entorno desactivado.
) else (
    echo [nd] El entorno virtual no estaba activo en esta sesion.
)
exit /b 0

:: ------------------------------------------------------------
:usage
echo.
echo  Uso:  nd ^<comando^>
echo.
echo  Comandos:
echo    init    Crea el entorno virtual, instala/actualiza dependencias.
echo    start   Activa el entorno y arranca el servidor (run.py).
echo    stop    Detiene el servidor uvicorn y desactiva el entorno.
echo.
exit /b 1
