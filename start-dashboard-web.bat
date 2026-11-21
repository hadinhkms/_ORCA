@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0"

if /i not "%~1"=="--run" (
    start "" wscript.exe "%~dp0start-dashboard-web.vbs" --open
    exit /b 0
)

echo [%date% %time%] Stopping old Orca Dashboard Web instances...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$procs = Get-CimInstance Win32_Process -Filter \"Name='node.exe'\" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like '*vite.web.config.ts*' }; foreach ($p in $procs) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }; $conns = Get-NetTCPConnection -LocalPort 5173 -State Listen -ErrorAction SilentlyContinue; foreach ($c in $conns) { if ($c.OwningProcess -gt 0) { Stop-Process -Id $c.OwningProcess -Force -ErrorAction SilentlyContinue } }"

ping -n 2 127.0.0.1 >nul

set "NODE_BIN="
for /d %%D in ("%~dp0out\runtimes\node-*") do (
    if exist "%%~fD\node.exe" set "NODE_BIN=%%~fD\node.exe"
)
if not defined NODE_BIN (
    if exist "%LOCALAPPDATA%\pnpm\bin\node.exe" (
        set "NODE_BIN=%LOCALAPPDATA%\pnpm\bin\node.exe"
    ) else (
        set "NODE_BIN=node"
    )
)

echo [%date% %time%] Starting Orca Dashboard Web using "!NODE_BIN!" on http://127.0.0.1:5173/web-index.html ...
"!NODE_BIN!" "%~dp0node_modules\vite\bin\vite.js" --config vite.web.config.ts --host 127.0.0.1
