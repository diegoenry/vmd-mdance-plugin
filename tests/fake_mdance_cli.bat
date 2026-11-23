@echo off
rem Windows runs no script by its #! line: Tcl takes only .exe, .com, .bat
rem and .cmd for programs. Runs tests/fake_mdance_cli with Python.
python "%~dp0fake_mdance_cli" %*
exit /b %ERRORLEVEL%
