@echo off
SET INNOSETUP=%CD%\nvm.iss
SET ORIG=%CD%
REM SET GOPATH=%CD%\src
SET GOBIN=%CD%\bin
SET GOARCH=386
SET version=1.1.7
SET DIST=%CD%\dist\%version%

echo Building NVM for Windows
echo Remove existing build at %DIST%
rd /s /q "%DIST%"
echo Creating %DIST%
mkdir "%DIST%"

echo Creating distribution in %DIST%

if exist src\nvm.exe (
  del src\nvm.exe
)

echo Building nvm.exe:

go build src\nvm.go

move nvm.exe %GOBIN%

for /f %%i in ('%GOBIN%\nvm.exe version') do set BUILT_VERSION=%%i

if NOT %BUILT_VERSION% == %version% (
  echo Expected nvm.exe version %version% but created version %BUILT_VERSION%
  exit 1
) else (
  echo nvm.exe v%BUILT_VERSION% built.
)

echo Codesign nvm.exe...
.\buildtools\signtools\x64\signtool.exe sign /debug /tr http://timestamp.digicert.com /td sha256 /fd sha256 /a %GOBIN%\nvm.exe

echo Building "noinstall" zip...
for %%a in (%GOBIN%) do (buildtools\zip -j -9 -r "%DIST%\nvm-noinstall.zip" "%CD%\LICENSE" "%%a\*" -x "%GOBIN%\nodejs.ico")

echo "Building the primary installer..."
buildtools\iscc %INNOSETUP% /o%DIST%
buildtools\zip -j -9 -r "%DIST%\nvm-setup.zip" "%DIST%\nvm-setup.exe"

echo "Generating Checksums for release files..."
for %%f in (%DIST%\*.*) do (certutil -hashfile "%%f" MD5 | find /i /v "md5" | find /i /v "certutil" >> "%%f.checksum.txt")

echo "Distribution created. Now cleaning up...."
del %GOBIN%\nvm.exe

echo "Done."
@echo on
