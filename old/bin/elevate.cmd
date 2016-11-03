@setlocal
@echo off
set CMD=%*
set APP=%1
start wscript //nologo "%~dpn0.vbs" %*
