@echo off
REM Simple Watch Folder Launcher
cd /d "%~dp0"

REM Backend starten
start "" /B powershell -NoProfile -WindowStyle Hidden -File "src\WatchFolderService.ps1" -ConfigPath "config\config.json"

REM Warten
ping localhost -n 2 >nul

REM Node.js prüfen
where node >nul 2>&1
if %errorlevel% equ 0 (
    REM Node.js da
    if not exist "node_modules" npm install >nul
    npm start
) else (
    REM Node.js fehlt
    start "" /B powershell -NoProfile -WindowStyle Hidden -File "src\SimpleWebServer.ps1"
    ping localhost -n 4 >nul
    start "" "http://localhost:8080"
)