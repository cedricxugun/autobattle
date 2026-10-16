@echo off
setlocal
set "WX_ROOT=%~dp0"
set "WX_ENGINE=%WX_ROOT%godot\tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
if not exist "%WX_ENGINE%" (
  echo Godot runtime is missing. Keep this launcher beside the godot folder.
  pause
  exit /b 1
)
start "" "%WX_ENGINE%" --path "%WX_ROOT%godot\wanxiang"
