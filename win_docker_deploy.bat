@echo off
setlocal EnableDelayedExpansion

REM Install rimraf if not present
echo Checking for rimraf...
call npm list -g rimraf >nul 2>&1
if errorlevel 1 (
    echo Installing rimraf globally...
    call npm install -g rimraf
)

REM Get Package Name
echo Getting package name from package.json...
for /f "tokens=* usebackq" %%a in (`node -p "require('./package.json').name"`) do (
    set PACKAGE_NAME=%%a
)

if "!PACKAGE_NAME!"=="" (
    echo Error: Could not determine package name from package.json.
    exit /b 1
)

REM Define local and container paths
set LOCAL_DIR=%~dp0dist
set VOLUME_NAME=self-n8n_n8n_storage
set CONTAINER_PATH=/custom/!PACKAGE_NAME!

echo Detected package name: '!PACKAGE_NAME!'
echo Local directory: "%LOCAL_DIR%"
echo Container path: "%CONTAINER_PATH%"

REM Build the Node
echo Building the node...
call pnpm run build

REM Clean up any existing temporary container
echo Cleaning up any existing temporary container...
docker rm -f deploy-temp1 2>nul

REM Deploy the Build Output
echo Creating temporary container...
docker run -dit --name deploy-temp1 -v %VOLUME_NAME%:/data busybox

echo Copying files into volume...
docker cp "%LOCAL_DIR%\." "deploy-temp1:/data%CONTAINER_PATH%"

echo Cleaning up container...
docker rm -f deploy-temp1

REM Step 5: Restart n8n
echo Restarting n8n...
docker container restart n8n

echo Deployment complete.

REM Show logs
echo Showing n8n logs (Press Ctrl+C to exit)...
docker logs -f n8n
