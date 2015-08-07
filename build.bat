@ECHO off
SET INNOSETUP=%CD%\nvm.iss
SET ORIG=%CD%
SET GOPATH=%CD%\src
SET GOBIN=%CD%\bin
SET GOARCH=386

REM Get the version number from the setup file
FOR /f "tokens=*" %%i IN ('FINDSTR /n . %INNOSETUP% ^| FINDSTR ^4:#define') DO SET L=%%i
SET version=%L:~24,-1%

REM Get the version number from the core executable
FOR /f "tokens=*" %%i IN ('FINDSTR /n . %GOPATH%\nvm.go ^| FINDSTR ^NvmVersion^| FINDSTR ^21^') DO SET L=%%i
SET goversion=%L:~18,-1%

IF NOT %version%==%goversion% GOTO VERSIONMISMATCH

SET DIST=%CD%\dist\%version%

REM Build the executable
ECHO Building NVM for Windows

WHERE goxc
IF %ERRORLEVEL% NEQ 0 GOTO :GOXCMISSING

CD %GOPATH%
goxc -arch="386" -os="windows" -n="nvm" -d="%GOBIN%" -o="%GOBIN%\nvm{{.Ext}}" -tasks-=package
CD %ORIG%

DEL /s /q %GOBIN%\nvm.exe
DEL /s /q %GOBIN%\src.exe
DEL /s /q %GOPATH%\src.exe
DEL /s /q %GOPATH%\nvm.exe

REM Clean the dist directory
RD /s /q "%DIST%"
MKDIR "%DIST%"

REM Create the "noinstall" zip
ECHO Generating nvm-noinstall.zip
FOR /d %%a IN (%GOBIN%) DO (buildtools\zip -j -9 -r "%DIST%\nvm-noinstall.zip" "%CD%\LICENSE" "%%a\*" -x "%GOBIN%\nodejs.ico")

REM Create the installer
ECHO Generating nvm-setup.zip
buildtools\iscc %INNOSETUP% /o%DIST%
buildtools\zip -j -9 -r "%DIST%\nvm-setup.zip" "%DIST%\nvm-setup.exe"
REM DEL /s /q "%DIST%\nvm-setup.exe"
ECHO --------------------------
ECHO Release %version% available in %DIST%
GOTO COMPLETE

:VERSIONMISMATCH
ECHO The version number in nvm.iss does not match the version in src\nvm.go
ECHO   - nvm.iss line #4: %version%
ECHO   - nvm.go line #21: %goversion%
EXIT /B

:GOXCMISSING
ECHO ERROR: goxc wasn't found -- source was not built
EXIT /B

:COMPLETE
@echo on
