@echo off
setlocal EnableDelayedExpansion

cd /d "%~dp0"

echo =======================================================
echo [%date% %time%] Bat dau dong bo Orca voi upstream...
echo Thu muc repo: %cd%
echo =======================================================

REM Tu dong bo qua cac file cache/lock .gradle bi thay doi trong mobile/
git checkout -- ":(glob)mobile/**/.gradle/**" >nul 2>&1

git diff --quiet
if errorlevel 1 goto :err_working_tree

git diff --cached --quiet
if errorlevel 1 goto :err_staged_changes

for /f "tokens=*" %%i in ('git branch --show-current') do set "CURRENT_BRANCH=%%i"
if not "%CURRENT_BRANCH%"=="main" (
    echo Dang chuyen sang nhanh main tu %CURRENT_BRANCH%...
    git checkout main
    if errorlevel 1 goto :err_checkout
)

echo [1/3] Dang fetch tu upstream...
git fetch upstream
if errorlevel 1 goto :err_fetch

for /f "tokens=*" %%a in ('git rev-parse HEAD') do set "LOCAL_REV=%%a"
for /f "tokens=*" %%b in ('git rev-parse upstream/main') do set "UPSTREAM_REV=%%b"

for /f "tokens=*" %%c in ('git merge-base HEAD upstream/main') do set "BASE_REV=%%c"
if "%BASE_REV%"=="%UPSTREAM_REV%" (
    echo [OK] Local main da dong bo voi upstream/main. Khong co commit moi can merge.
    goto :check_push
)

echo [2/3] Dang merge upstream/main vao main...
git merge upstream/main --no-edit
if errorlevel 1 goto :err_merge

:check_push
echo [3/3] Dang push len origin main...
git push origin main
if errorlevel 1 goto :err_push

echo =======================================================
echo [THANH CONG] Dong bo hoan tat luc %date% %time%!
echo =======================================================
goto :end

:err_working_tree
echo [CANH BAO] Co file bi thay doi trong working tree. Khong the tu dong merge.
goto :error

:err_staged_changes
echo [CANH BAO] Co file da staged chua commit. Khong the tu dong merge.
goto :error

:err_checkout
echo [LOI] Khong the chuyen sang nhanh main!
goto :error

:err_fetch
echo [LOI] Fetch upstream that bai!
goto :error

:err_merge
echo [LOI] Xung dot (conflict) khi merge!
echo Vui long mo IDE xu ly xung dot thu cong.
goto :error

:err_push
echo [LOI] Push len origin main that bai!
goto :error

:error
echo =======================================================
echo [THAT BAI] Qua trinh dong bo gap loi!
echo =======================================================
if not "%1"=="--silent" pause
exit /b 1

:end
if not "%1"=="--silent" pause
exit /b 0
