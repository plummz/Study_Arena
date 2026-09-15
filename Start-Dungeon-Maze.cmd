@echo off
setlocal
cd /d "%~dp0"
set "GODOT_EXE=%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT_EXE%" (
  echo Godot was not found at:
  echo %GODOT_EXE%
  echo Move Godot back to Downloads or edit GODOT_EXE in this launcher.
  pause
  exit /b 1
)
if not exist "%CD%\godot\dungeon_maze\assets\companions" mkdir "%CD%\godot\dungeon_maze\assets\companions"
xcopy /Y /Q "%CD%\web\assets\companions\*.png" "%CD%\godot\dungeon_maze\assets\companions\" >nul
start "Study Arena Dungeon" "%GODOT_EXE%" --path "%CD%\godot\dungeon_maze"
endlocal
