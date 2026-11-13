@echo off
setlocal

if defined FIRETENDER_GODOT goto launch
if exist "%~dp0PLAY.local.cmd" call "%~dp0PLAY.local.cmd"
if defined FIRETENDER_GODOT goto launch
if exist "%~dp0Godot.exe" set "FIRETENDER_GODOT=%~dp0Godot.exe"
if defined FIRETENDER_GODOT goto launch
for /f "delims=" %%G in ('where Godot.exe 2^>nul') do if not defined FIRETENDER_GODOT set "FIRETENDER_GODOT=%%G"
if defined FIRETENDER_GODOT goto launch
echo Open project.godot in Godot 4 and press F5.
echo To use this launcher, set FIRETENDER_GODOT to the path of your Godot 4 executable.
pause
exit /b 1

:launch
if not exist "%FIRETENDER_GODOT%" (
    echo FIRETENDER_GODOT does not point to an executable file.
    pause
    exit /b 1
)
start "" "%FIRETENDER_GODOT%" --path "%~dp0."
