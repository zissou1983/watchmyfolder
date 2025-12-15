@echo off
setlocal enabledelayedexpansion

REM Kill all PowerShell processes
taskkill /F /IM powershell.exe /T 2>nul

timeout /t 2 /nobreak

REM Start Watch Folder Service in background
cd /d E:\GitHub\watchmyfolder
echo Starting Watch Folder Service...
start "" powershell -NoProfile -ExecutionPolicy Bypass -File "src\WatchFolderService.ps1"

timeout /t 3 /nobreak

REM Create test file
echo Creating test file...
(
echo Test data from batch
echo Date: %date% %time%
) > C:\Temp\Incoming\batch-test.txt

echo Test file created. Waiting 20 seconds...
timeout /t 20 /nobreak

REM Check results
echo.
echo === Checking Night folder ===
dir C:\Temp\Night
echo.
echo === Checking Incoming folder ===
dir C:\Temp\Incoming

pause
