@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0"

if /i not "%~1"=="--run" (
    start "" wscript.exe "%~dp0start-dashboard-web.vbs" --open
    exit /b 0
)

set "NODE_BIN="
set "NODE_DIR="
for /d %%D in ("%~dp0out\runtimes\node-*") do (
    if exist "%%~fD\node.exe" (
        set "NODE_BIN=%%~fD\node.exe"
        set "NODE_DIR=%%~fD"
    )
)
if not defined NODE_BIN (
    if exist "%LOCALAPPDATA%\pnpm\bin\node.exe" (
        set "NODE_BIN=%LOCALAPPDATA%\pnpm\bin\node.exe"
        set "NODE_DIR=%LOCALAPPDATA%\pnpm\bin"
    ) else (
        set "NODE_BIN=node"
    )
)
if defined NODE_DIR set "PATH=%NODE_DIR%;%PATH%"
if exist "%APPDATA%\npm" set "PATH=%APPDATA%\npm;!PATH!"
if exist "%LOCALAPPDATA%\pnpm" set "PATH=%LOCALAPPDATA%\pnpm;!PATH!"

powershell -NoProfile -ExecutionPolicy Bypass -Command "$c = Get-NetTCPConnection -LocalPort 6769 -State Listen -ErrorAction SilentlyContinue; if ($c) { exit 0 } else { exit 1 }"
if not errorlevel 1 (
    echo [%date% %time%] Orca Host already listening on port 6769. > "%~dp0start-dashboard-web.log"
    exit /b 0
)

echo [%date% %time%] Starting Orca Host (single port 6769 for Web + Mobile) using "!NODE_BIN!" ... > "%~dp0start-dashboard-web.log"
if not exist "%~dp0out\web\web-index.html" (
    echo [%date% %time%] Building out\web bundle ... >> "%~dp0start-dashboard-web.log"
    "!NODE_BIN!" "%~dp0node_modules\vite\bin\vite.js" build --config vite.web.config.ts >> "%~dp0start-dashboard-web.log" 2>&1
    if errorlevel 1 exit /b %errorlevel%
)

"!NODE_BIN!" "%~dp0config\scripts\workspace-package-build\build-workspace-packages.mjs" >> "%~dp0start-dashboard-web.log" 2>&1
if errorlevel 1 exit /b %errorlevel%
if not exist "%~dp0out\cli\index.js" (
    echo [%date% %time%] Building out\cli bundle ... >> "%~dp0start-dashboard-web.log"
    if not defined ORCA_CLI_BUILD_COMPILER set "ORCA_CLI_BUILD_COMPILER=tsrs"
    "!NODE_BIN!" "%~dp0config\scripts\cli-build\build-cli.mjs" >> "%~dp0start-dashboard-web.log" 2>&1
    if errorlevel 1 exit /b %errorlevel%
    "!NODE_BIN!" "%~dp0config\scripts\cli-build\verify-cli-bin.mjs" --fix-executable --fix-package-json >> "%~dp0start-dashboard-web.log" 2>&1
    if errorlevel 1 exit /b %errorlevel%
)
"!NODE_BIN!" "%~dp0config\scripts\native-build\node-addons\ensure-native-runtime.mjs" --runtime=electron >> "%~dp0start-dashboard-web.log" 2>&1
if errorlevel 1 exit /b %errorlevel%
"!NODE_BIN!" "%~dp0config\scripts\development\launch\run-electron-vite-dev.mjs" -- --orca-start-in-tray >> "%~dp0start-dashboard-web.log" 2>&1
exit /b %errorlevel%
