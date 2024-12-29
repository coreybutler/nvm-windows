@setlocal
@echo off

:: Try without elevation, in case %NVM_SYMLINK% is a user-owned path and the 
:: machine has Windows 10 Developer Mode enabled
%*
if %ERRORLEVEL% LSS 1 goto :EOF

:: The command failed without elevation, try with elevation
set CMD=%*
set APP=%1
start wscript //nologo "%~dpn0.vbs" %*
