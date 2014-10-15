@echo off
SET INNOSETUP=%CD%\nvm.iss
SET ORIG=%CD%
SET GOPATH=%CD%\src
SET GOBIN=%CD%\bin
SET GOARCH=386

REM Get the version number from the setup file
for /f "tokens=*" %%i in ('findstr /n . %INNOSETUP% ^| findstr ^4:#define') do set L=%%i
set version=%L:~24,-1%

REM Get the version number from the core executable
for /f "tokens=*" %%i in ('findstr /n . %GOPATH%\nvm.go ^| findstr ^NvmVersion^| findstr ^21^') do set L=%%i
set goversion=%L:~19,-1%

IF NOT %version%==%goversion% GOTO VERSIONMISMATCH

SET DIST=%CD%\dist\%version%

REM Build the executable
echo Building NVM for Windows
rm %GOBIN%\nvm.exe
cd %GOPATH%
goxc -arch="386" -os="windows" -n="nvm" -d="%GOBIN%" -o="%GOBIN%\nvm{{.Ext}}" -tasks-=package
cd %ORIG%
rm %GOBIN%\src.exe
rm %GOPATH%\src.exe
rm %GOPATH%\nvm.exe

REM Clean the dist directory
rm -rf "%DIST%"
mkdir "%DIST%"

REM Create the "noinstall" zip
echo Generating nvm-noinstall.zip
for /d %%a in (%GOBIN%) do (buildtools\zip -j -9 -r "%DIST%\nvm-noinstall.zip" "%CD%\LICENSE" "%%a\*" -x "%GOBIN%\nodejs.ico")

REM Create the installer
echo Generating nvm-setup.zip
buildtools\iscc %INNOSETUP% /o%DIST%
buildtools\zip -j -9 -r "%DIST%\nvm-setup.zip" "%DIST%\nvm-setup.exe"
rm "%DIST%\nvm-setup.exe"
echo --------------------------
echo Release %version% available in %DIST%
GOTO COMPLETE

:VERSIONMISMATCH
echo The version number in nvm.iss does not match the version in src\nvm.go
echo   - nvm.iss line #4: %version%
echo   - nvm.go line #21: %goversion%
EXIT /B

:COMPLETE
@echo on
