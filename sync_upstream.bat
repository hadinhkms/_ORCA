@echo off
setlocal EnableDelayedExpansion

cd /d "%~dp0"

echo =======================================================
echo [%date% %time%] Bat dau dong bo Orca voi upstream...
echo Thu muc repo: %cd%
echo =======================================================

REM Tu dong bo qua cac file cache/lock .gradle bi thay doi trong mobile/
git checkout -- ":(glob)mobile/**/.gradle/**" >nul 2>&1

set "DID_STASH=0"
set "STASH_POP_ERR=0"

git status --porcelain -- . ":(exclude)sync_upstream.bat" | findstr . >nul
if not errorlevel 1 (
    echo [0/4] Dang tam luu cac thay doi local ^(git stash -u^)...
    git stash push -u -m "sync_upstream auto-stash" -- . ":(exclude)sync_upstream.bat"
    if errorlevel 1 goto :err_stash
    set "DID_STASH=1"
)

for /f "tokens=*" %%i in ('git branch --show-current') do set "CURRENT_BRANCH=%%i"
if not "%CURRENT_BRANCH%"=="main" (
    echo Dang chuyen sang nhanh main tu %CURRENT_BRANCH%...
    git checkout main
    if errorlevel 1 goto :err_checkout
)

echo [1/4] Dang fetch tu origin va upstream...
git fetch origin
if errorlevel 1 goto :err_fetch_origin
git fetch upstream
if errorlevel 1 goto :err_fetch

for /f "tokens=*" %%o in ('git rev-parse origin/main') do set "ORIGIN_REV=%%o"
for /f "tokens=*" %%m in ('git merge-base HEAD origin/main') do set "ORIGIN_BASE_REV=%%m"
if not "%ORIGIN_BASE_REV%"=="%ORIGIN_REV%" (
    echo [2a/4] Dang merge origin/main vao main...
    git merge origin/main --no-edit
    if errorlevel 1 goto :err_merge_origin
)

for /f "tokens=*" %%a in ('git rev-parse HEAD') do set "LOCAL_REV=%%a"
for /f "tokens=*" %%b in ('git rev-parse upstream/main') do set "UPSTREAM_REV=%%b"

for /f "tokens=*" %%c in ('git merge-base HEAD upstream/main') do set "BASE_REV=%%c"
if "%BASE_REV%"=="%UPSTREAM_REV%" (
    echo [OK] Local main da dong bo voi upstream/main. Khong co commit moi can merge.
    goto :check_push
)

echo [2/4] Dang merge upstream/main vao main ^(giu local neu conflict^)...
git merge upstream/main -X ours --no-edit
if errorlevel 1 goto :err_merge

:check_push
echo [3/4] Dang push len origin main...
git push origin main
if errorlevel 1 goto :err_push

call :restore_stash
if "!STASH_POP_ERR!"=="1" goto :error

echo =======================================================
echo [THANH CONG] Dong bo hoan tat luc %date% %time%!
echo =======================================================
goto :end

:err_stash
echo [LOI] Khong the stash cac thay doi local!
goto :error

:err_checkout
echo [LOI] Khong the chuyen sang nhanh main!
goto :error

:err_fetch_origin
echo [LOI] Fetch origin that bai!
goto :error

:err_fetch
echo [LOI] Fetch upstream that bai!
goto :error

:err_merge_origin
echo [LOI] Xung dot ^(conflict^) khi merge origin/main vao main!
git merge --abort >nul 2>&1
goto :error

:err_merge
echo [LOI] Xung dot ^(conflict^) khi merge ke ca voi -X ours!
git merge --abort >nul 2>&1
goto :error

:err_push
echo [LOI] Push len origin main that bai!
goto :error

:restore_stash
if "!DID_STASH!"=="1" (
    echo [4/4] Dang khoi phuc cac thay doi local tu stash...
    git stash pop
    if errorlevel 1 (
        echo [CANH BAO] Co xung dot khi khoi phuc file local tu stash.
        echo Cac thay doi van duoc giu an toan trong git stash. Vui long kiem tra lai trong IDE.
        set "STASH_POP_ERR=1"
    )
    set "DID_STASH=0"
)
exit /b 0

:error
call :restore_stash
echo =======================================================
echo [THAT BAI] Qua trinh dong bo gap loi!
echo =======================================================
if not "%1"=="--silent" pause
exit /b 1

:end
if not "%1"=="--silent" pause
exit /b 0
