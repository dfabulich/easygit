@echo off
set SCRIPT_DIR=%~dp0
set SCRIPT_DIR=%SCRIPT_DIR:\=/%
perl %SCRIPT_DIR%eg %*
exit /b %errorlevel%