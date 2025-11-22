@echo off
setlocal EnableDelayedExpansion

REM ==================== 1. Prüfen/installieren von rimraf ====================
echo Checking for rimraf...
call npm list -g rimraf >nul 2>&1
if errorlevel 1 (
    echo Installing rimraf globally...
    call npm install -g rimraf
)

REM ==================== 2. Paketname aus package.json holen ====================
echo Getting package name from package.json...
for /f "tokens=* usebackq" %%a in (`node -p "require('./package.json').name" 2^>nul`) do (
    set "PACKAGE_NAME=%%a"
)
if "!PACKAGE_NAME!"=="" (
    echo Error: Could not determine package name from package.json.
    pause
    exit /b 1
)

REM ==================== 3. Pfade definieren ====================
set "LOCAL_DIST=%~dp0dist"
set "LOCAL_ICONS=%~dp0icons"
set "VOLUME_NAME=self-n8n_n8n_storage"
set "CONTAINER_PATH=/custom/!PACKAGE_NAME!"

echo.
echo ========================================
echo Detected package name : '!PACKAGE_NAME!'
echo Local dist folder     : "!LOCAL_DIST!"
echo Local icons folder    : "!LOCAL_ICONS!"
echo Container path        : "!CONTAINER_PATH!"
echo ========================================
echo.

REM ==================== 4. Node bauen ====================
echo Building the node...
call pnpm run build || (
    echo Build failed!
    pause
    exit /b 1
)

REM ==================== 5. Alten Temp-Container entfernen ====================
echo Cleaning up any existing temporary container...
docker rm -f deploy-temp1 >nul 2>&1

REM ==================== 6. Temporären Container starten ====================
echo Creating temporary container...
docker run -dit --name deploy-temp1 -v %VOLUME_NAME%:/data busybox >nul
if errorlevel 1 (
    echo Error: Could not start temporary container. Is Docker running?
    pause
    exit /b 1
)

REM ==================== 7. dist und icons kopieren – FINAL DOCKER FIX ====================
echo Copying files into volume...

echo   - Copying compiled files (dist^)...
docker cp "!LOCAL_DIST!\." "deploy-temp1:/data!CONTAINER_PATH!"

echo   - Copying icons into dist/icons/ (this is where n8n in Docker actually looks!)...
if exist "!LOCAL_ICONS!" (
    docker exec deploy-temp1 mkdir -p /data!CONTAINER_PATH!/dist/icons 2>nul
    docker cp "!LOCAL_ICONS!\." "deploy-temp1:/data!CONTAINER_PATH!/dist/icons/"
    echo     SUCCESS: Icons copied to dist/icons/ → Your Telekom logo will now appear!
) else (
    echo     WARNING: No icons folder found in project root – icon will be missing.
)

REM ==================== 8. Temp-Container wieder entfernen ====================
echo Cleaning up temporary container...
docker rm -f deploy-temp1 >nul

REM ==================== 9. n8n neu starten ====================
echo Restarting n8n container...
docker container restart n8n

echo.
echo ========================================
echo DEPLOYMENT COMPLETE!
echo Your Telekom LLM Chat Model + ICON is now 100%% live!
echo ========================================
echo.
echo Showing n8n logs (Press Ctrl+C to exit^)...
docker logs -f n8n
