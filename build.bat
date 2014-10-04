@echo off
SET INNOSETUP=%CD%\nvm.iss

REM Get the version number from the setup file
for /f "tokens=*" %%i in ('findstr /n . %INNOSETUP% ^| findstr ^4:#define') do set L=%%i
set version=%L:~24,-1%

REM Build the executable
echo Building NVM for Windows
SET DIST=%CD%\dist\%version%
SET GOPATH=%CD%\src
SET GOBIN=%CD%\bin
go build -o %GOBIN%\nvm.exe %GOPATH%\nvm.go


REM Create the "noinstall" zip
echo Generating nvm-noinstall.zip
for /d %%a in (%GOBIN%) do (buildtools\zip -j -9 -r "%DIST%\nvm-noinstall.zip" "%CD%\LICENSE" "%%a\*" -x "%GOBIN%\nodejs.ico")

REM Create the installer
echo Generating nvm-setup.zip
buildtools\iscc %INNOSETUP% /o%DIST%
buildtools\zip -j -9 -r "%DIST%\nvm-setup.zip" "%DIST%\nvm-setup.exe"
rm "%DIST%\nvm-setup.exe"

cls
echo Release %version% available in %DIST%

@echo on
