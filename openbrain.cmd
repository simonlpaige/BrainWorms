@echo off
rem open-brain launcher: serves the static dashboard on http://127.0.0.1:18900/
rem To autostart at logon, copy this file (or a shortcut to it) to:
rem   %APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\
setlocal
cd /d "%~dp0"
"C:\Python314\python.exe" -m http.server 18900 --bind 127.0.0.1
