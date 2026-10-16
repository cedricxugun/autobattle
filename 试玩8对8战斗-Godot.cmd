@echo off
setlocal
set "WX_ROOT=%~dp0"
start "" "%WX_ROOT%godot\tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe" --path "%WX_ROOT%godot\wanxiang" -- --qa --demo=-2
