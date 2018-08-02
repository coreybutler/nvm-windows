@echo off
SET INNOSETUP=%CD%\nvm.iss
SET ORIG=%CD%
REM SET GOPATH=%CD%\src
SET GOBIN=%CD%\bin
SET GOARCH=386
SET version=1.1.7

REM Get the version number from the setup file
REM for /f "tokens=*" %%i in ('findstr /n . %INNOSETUP% ^| findstr ^4:#define') do set L=%%i
REM set version=%L:~24,-1%

REM Get the version number from the core executable
REM for /f "tokens=*" %%i in ('findstr /n . %GOPATH%\nvm.go ^| findstr ^NvmVersion^| findstr ^21^') do set L=%%i
REM set goversion=%L:~19,-1%

REM IF NOT %version%==%goversion% GOTO VERSIONMISMATCH

SET DIST=%CD%\dist\%version%

REM Build the executable
echo Building NVM for Windows
REM rm %GOBIN%\nvm.exe
REM cd %GOPATH%
echo "=========================================>"
REM echo %GOBIN%
REM goxc -arch="386" -os="windows" -n="nvm" -d="%GOBIN%" -o="%GOBIN%\nvm{{.Ext}}" -tasks-=package

REM cd %ORIG%
REM rm %GOBIN%\src.exe
REM rm %GOPATH%\src.exe
REM rm %GOPATH%\nvm.exe

REM Clean the dist directory
rm -rf "%DIST%"
mkdir "%DIST%"

echo Creating distribution in %DIST%

if exist src\nvm.exe (
  rm src\nvm.exe
)

echo "Building nvm.exe...."

go build src\nvm.go
mv nvm.exe %GOBIN%

echo Building "noinstall" zip...
for /d %%a in (%GOBIN%) do (buildtools\zip -j -9 -r "%DIST%\nvm-noinstall.zip" "%CD%\LICENSE" "%%a\*" -x "%GOBIN%\nodejs.ico")

echo "Building the primary installer..."
buildtools\iscc %INNOSETUP% /o%DIST%
buildtools\zip -j -9 -r "%DIST%\nvm-setup.zip" "%DIST%\nvm-setup.exe"
echo "Generating Checksums for release files..."

for /r %i in (*.zip *.exe) do checksum -file %i -t sha256 >> %i.sha256.txt
echo "Distribution created. Now cleaning up...."
rm %GOBIN%/nvm.exe

echo "Done."
@echo on
