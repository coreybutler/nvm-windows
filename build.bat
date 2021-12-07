@echo off
SET INNOSETUP=%CD%\nvm.iss
SET ORIG=%CD%
REM SET GOPATH=%CD%\src
SET GOBIN=%CD%\bin
REM Support for older architectures
SET GOARCH=386

REM Cleanup existing build if it exists
if exist src\nvm.exe (
  del src\nvm.exe
)

REM Make the executable and add to the binary directory
echo Building nvm.exe
cd .\src
go build nvm.go

REM Group the file with the helper binaries
move nvm.exe %GOBIN%
cd ..\

REM Codesign the executable
echo Sign the nvm executable...
buildtools\signtool.exe sign /debug /tr http://timestamp.sectigo.com /td sha256 /fd sha256 /a %GOBIN%\nvm.exe

for /f %%i in ('"%GOBIN%\nvm.exe" version') do set AppVersion=%%i
echo nvm.exe v%AppVersion% built.

REM Create the distribution folder
SET DIST=%CD%\dist\%AppVersion%

REM Remove old build files if they exist.
if exist %DIST% (
  echo Clearing old build in %DIST%
  rd /s /q "%DIST%"
)

REM Create the distribution directory
mkdir "%DIST%"

REM Create the "no install" zip version
for %%a in ("%GOBIN%") do (buildtools\zip -j -9 -r "%DIST%\nvm-noinstall.zip" "%CD%\LICENSE" %%a\* -x "%GOBIN%\nodejs.ico")

REM Generate update utility
echo Generating update utility...
cd .\updater
go build nvm-update.go
echo Sign the updater...
buildtools\signtool.exe sign /debug /tr http://timestamp.sectigo.com /td sha256 /fd sha256 /a nvm-update.exe
move nvm-update.exe %DIST%
cd ..\

REM Generate the installer (InnoSetup)
echo Generating installer...
buildtools\iscc "%INNOSETUP%" "/o%DIST%"
echo Sign the installer
buildtools\signtool.exe sign /debug /tr http://timestamp.sectigo.com /td sha256 /fd sha256 /a %DIST%\nvm-setup.exe
echo Bundle the installer/updater...
buildtools\zip -j -9 -r "%DIST%\nvm-setup.zip" "%DIST%\nvm-setup.exe"
buildtools\zip -j -9 -r "%DIST%\nvm-update.zip" "%DIST%\nvm-update.exe"

del %DIST%\nvm-update.exe
del %DIST%\nvm-setup.exe

REM Generate checksums
echo Generating checksums...
for %%f in (%DIST%\*.*) do (certutil -hashfile "%%f" MD5 | find /i /v "md5" | find /i /v "certutil" >> "%%f.checksum.txt")

echo Cleaning up...
REM Cleanup
del %GOBIN%\nvm.exe
@REM del %GOBIN%\nvm-update.exe
@REM del %GOBIN%\nvm-setup.exe

echo NVM for Windows v%AppVersion% build completed.
@echo on
