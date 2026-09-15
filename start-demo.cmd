@echo off
cd /d "%~dp0"
where node >nul 2>nul
if errorlevel 1 (
  java -Xmx256m -jar dist\study-arena.jar --demo
) else (
  node scripts\start-windows.mjs
)
pause
