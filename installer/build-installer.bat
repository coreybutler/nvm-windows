@echo off
setlocal EnableDelayedExpansion

rem Build NVM for Windows installer using Inno Setup.
rem Usage:
rem   build-installer.bat
rem   build-installer.bat 2.0.0-alpha.1
rem   build-installer.bat 2.0.0-alpha.1 AuthorSoftware.NVMWindows
rem   build-installer.bat 2.0.0-alpha.1 AuthorSoftware.NVMWindows 40078385-F676-4C61-9A9C-F9028599D6D3 amd64
rem   build-installer.bat 2.0.0-alpha.1 AuthorSoftware.NVMWindows 40078385-F676-4C61-9A9C-F9028599D6D3 amd64 (all args optional; defaults from manifest)

set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "ROOT_DIR=%SCRIPT_DIR%\.."
set "DIST_DIR=%ROOT_DIR%\.dist"
set "SETUP_ISS=%SCRIPT_DIR%\setup.iss"
set "MANIFEST=%ROOT_DIR%\cli\src\manifest.json"
if not exist "%MANIFEST%" set "MANIFEST=%ROOT_DIR%\nvm\src\manifest.json"
set "ARCHITECTURE=%~4"
if "%ARCHITECTURE%"=="" set "ARCHITECTURE=amd64"
set "LICENSE_SRC=%ROOT_DIR%\LICENSE"
set "LICENSE_DST=%SCRIPT_DIR%\LICENSE"

if not exist "%SETUP_ISS%" (
  echo ERROR: setup.iss not found at "%SETUP_ISS%"
  exit /b 1
)

if not exist "%MANIFEST%" (
  echo ERROR: manifest.json not found at "%MANIFEST%"
  exit /b 1
)

if "%~1"=="" (
  for /f "usebackq delims=" %%V in (`powershell -NoProfile -Command "(Get-Content -Raw '%MANIFEST%' | ConvertFrom-Json).version"`) do set "VERSION=%%V"
) else (
  set "VERSION=%~1"
)

if "%~2"=="" (
  for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "(Get-Content -Raw '%MANIFEST%' | ConvertFrom-Json).appUserModelId"`) do set "APP_USER_MODEL_ID=%%A"
) else (
  set "APP_USER_MODEL_ID=%~2"
)

if "%~3"=="" (
  for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "(Get-Content -Raw '%MANIFEST%' | ConvertFrom-Json).appId"`) do set "APP_ID=%%I"
) else (
  set "APP_ID=%~3"
)

for /f "usebackq delims=" %%P in (`powershell -NoProfile -Command "(Get-Content -Raw '%MANIFEST%' | ConvertFrom-Json).author"`) do set "PUBLISHER=%%P"
for /f "usebackq delims=" %%N in (`powershell -NoProfile -Command "(Get-Content -Raw '%MANIFEST%' | ConvertFrom-Json).name"`) do set "ALIAS=%%N"
for /f "usebackq delims=" %%N in (`powershell -NoProfile -Command "(Get-Content -Raw '%MANIFEST%' | ConvertFrom-Json).appLabel"`) do set "APP_LABEL=%%N"
for /f "usebackq delims=" %%O in (`powershell -NoProfile -Command "(Get-Content -Raw '%MANIFEST%' | ConvertFrom-Json).appOrgLabel"`) do set "APP_ORG_LABEL=%%O"
for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "(Get-Content -Raw '%MANIFEST%' | ConvertFrom-Json).description"`) do set "DESCRIPTION=%%D"
for /f "usebackq delims=" %%U in (`powershell -NoProfile -Command "(Get-Content -Raw '%MANIFEST%' | ConvertFrom-Json).appUrl"`) do set "APP_URL=%%U"

if "%VERSION%"=="" (
  echo ERROR: Could not determine version.
  exit /b 1
)

for /f "usebackq delims=" %%V in (`powershell -NoProfile -Command "$v = '%VERSION%'; if ($v -match '^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)(?:-(?:\d+\.\d+\.\d+-)?[A-Za-z]+\.(?<rev>\d+))?$') { $rev = if ($matches['rev']) { [int]$matches['rev'] } else { 0 }; '{0}.{1}.{2}.{3}' -f [int]$matches['major'], [int]$matches['minor'], [int]$matches['patch'], $rev } else { Write-Error ('Unsupported version format: ' + $v); exit 1 }"`) do set "VERSION_INFO_VERSION=%%V"

if "%VERSION_INFO_VERSION%"=="" (
  echo ERROR: Could not derive numeric VersionInfoVersion from "%VERSION%".
  exit /b 1
)

if "%APP_USER_MODEL_ID%"=="" (
  echo ERROR: Could not determine AppUserModelId.
  exit /b 1
)

if "%APP_ID%"=="" (
  echo ERROR: Could not determine AppId.
  exit /b 1
)

if "%PUBLISHER%"=="" (
  echo ERROR: Could not determine Publisher from manifest author.
  exit /b 1
)

if "%ALIAS%"=="" (
  echo ERROR: Could not determine Alias from manifest name.
  exit /b 1
)

if "%APP_LABEL%"=="" (
  echo ERROR: Could not determine AppLabel.
  exit /b 1
)

if "%APP_ORG_LABEL%"=="" (
  echo ERROR: Could not determine AppOrgLabel.
  exit /b 1
)

if "%DESCRIPTION%"=="" (
  echo ERROR: Could not determine Description.
  exit /b 1
)

if "%APP_URL%"=="" (
  echo ERROR: Could not determine AppUrl.
  exit /b 1
)

set "ISCC="
if exist "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" set "ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if not defined ISCC if exist "%ProgramFiles%\Inno Setup 6\ISCC.exe" set "ISCC=%ProgramFiles%\Inno Setup 6\ISCC.exe"
if not defined ISCC if exist "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" set "ISCC=%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe"

if not defined ISCC (
  for /f "usebackq delims=" %%I in (`where iscc 2^>nul`) do (
    set "ISCC=%%I"
    goto :iscc_found
  )
)

:iscc_found
if not defined ISCC (
  echo ERROR: ISCC.exe not found. Install Inno Setup 6 or add ISCC to PATH.
  exit /b 1
)

if exist "%LICENSE_SRC%" (
  copy /Y "%LICENSE_SRC%" "%LICENSE_DST%" >nul
)

if not exist "%DIST_DIR%" mkdir "%DIST_DIR%" >nul 2>nul

set "ARCH_TOKEN=%ARCHITECTURE%"
if /I "%ARCHITECTURE%"=="amd64" set "ARCH_TOKEN=x64"
set "OUTPUT_BASENAME=%ALIAS%-%VERSION%-%ARCH_TOKEN%-setup"
set "BUILD_OUTPUT_BASENAME=%OUTPUT_BASENAME%"
set "OUTPUT_FILE=%DIST_DIR%\%BUILD_OUTPUT_BASENAME%.exe"
set "LEGACY_OUTPUT_FILE=%DIST_DIR%\%ALIAS%-%VERSION%-amd64-setup.exe"

if /I not "%OUTPUT_FILE%"=="%LEGACY_OUTPUT_FILE%" (
  if exist "%LEGACY_OUTPUT_FILE%" del /q "%LEGACY_OUTPUT_FILE%"
)

if exist "%OUTPUT_FILE%" (
  set "OUTPUT_PREP=UNKNOWN"
  for /f "usebackq delims=" %%S in (`powershell -NoProfile -Command "$path = '%OUTPUT_FILE%'; try { Remove-Item -LiteralPath $path -Force -ErrorAction Stop; 'REMOVED' } catch { 'LOCKED' }"`) do set "OUTPUT_PREP=%%S"

  if /I "!OUTPUT_PREP!"=="LOCKED" (
    for /f "usebackq delims=" %%T in (`powershell -NoProfile -Command "Get-Date -Format 'yyyyMMddHHmmss'"`) do set "OUTPUT_TIMESTAMP=%%T"
    set "BUILD_OUTPUT_BASENAME=!OUTPUT_BASENAME!-!OUTPUT_TIMESTAMP!"
    set "OUTPUT_FILE=%DIST_DIR%\!BUILD_OUTPUT_BASENAME!.exe"
    echo WARNING: Canonical output is locked. Building to "!OUTPUT_FILE!" instead.
  )
)

echo Building installer version %VERSION%
echo Using Alias: %ALIAS%
echo Using AppLabel: %APP_LABEL%
echo Using AppOrgLabel: %APP_ORG_LABEL%
echo Using AppUserModelId: %APP_USER_MODEL_ID%
echo Using AppId: %APP_ID%
echo Using Publisher: %PUBLISHER%
echo Using AppUrl: %APP_URL%
echo Using Architecture: %ARCHITECTURE%
echo Using VersionInfoVersion: %VERSION_INFO_VERSION%
echo Using ISCC: %ISCC%

pushd "%SCRIPT_DIR%"
"%ISCC%" /DVersion=%VERSION% /DVersionInfoVersion=%VERSION_INFO_VERSION% /DAppUserModelId=%APP_USER_MODEL_ID% /DAppId=%APP_ID% "/DPublisher=%PUBLISHER%" "/DOrgLabel=%APP_ORG_LABEL%" "/DAlias=%ALIAS%" "/DName=%APP_LABEL%" "/DDescription=%DESCRIPTION%" "/DURL=%APP_URL%" /DArchitecture=%ARCHITECTURE% /DOutputFileName=%BUILD_OUTPUT_BASENAME% "%SETUP_ISS%"
set "BUILD_EXIT=%ERRORLEVEL%"
popd

if not "%BUILD_EXIT%"=="0" (
  echo Build failed with exit code %BUILD_EXIT%.
  exit /b %BUILD_EXIT%
)

echo Build succeeded.
echo Output: %OUTPUT_FILE%
exit /b 0
