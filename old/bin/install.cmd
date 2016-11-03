@echo off
set /P NVM_PATH="Enter the absolute path where the zip file is extracted/copied to: "
setx /M NVM_HOME "%NVM_PATH%"
setx /M NVM_SYMLINK "C:\Program Files\nodejs"
setx /M PATH "%PATH%;%NVM_HOME%;%NVM_SYMLINK%"

if exist "%SYSTEMDRIVE%\Program Files (x86)\" (
set SYS_ARCH=64
) else (
set SYS_ARCH=32
)
(echo root: %NVM_HOME% && echo path: %NVM_SYMLINK% && echo arch: %SYS_ARCH% && echo proxy: none) > %NVM_HOME%\settings.txt

notepad %NVM_HOME%\settings.txt
@echo on
