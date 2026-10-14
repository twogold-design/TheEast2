@echo off
setlocal EnableExtensions
title The East - Rebuild 3D Assets

set "PROJECT_ROOT=%~dp0"
if "%PROJECT_ROOT:~-1%"=="\" set "PROJECT_ROOT=%PROJECT_ROOT:~0,-1%"
set "BLENDER_EXE=D:\tools\blender\setup\blender.exe"
set "GENERATOR=%PROJECT_ROOT%\tools\generate_lowpoly_assets.py"
set "BLENDER_DATA=%PROJECT_ROOT%\.blender-user"

if not exist "%BLENDER_EXE%" (
  echo Blender was not found:
  echo %BLENDER_EXE%
  pause
  exit /b 1
)

if not exist "%GENERATOR%" (
  echo Asset generator was not found:
  echo %GENERATOR%
  pause
  exit /b 2
)

if /I "%~1"=="check" (
  echo Asset generator is ready.
  echo Project:   %PROJECT_ROOT%
  echo Blender:   %BLENDER_EXE%
  echo Generator: %GENERATOR%
  exit /b 0
)

set "THE_EAST_PROJECT=%PROJECT_ROOT%"
set "APPDATA=%BLENDER_DATA%\AppData\Roaming"
set "LOCALAPPDATA=%BLENDER_DATA%\AppData\Local"
set "TEMP=%BLENDER_DATA%\Temp"
set "TMP=%BLENDER_DATA%\Temp"

if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%"
if not exist "%TEMP%" mkdir "%TEMP%"

pushd "%PROJECT_ROOT%" || exit /b 3
"%BLENDER_EXE%" --background --factory-startup --python "%GENERATOR%"
set "EXIT_CODE=%ERRORLEVEL%"
popd

if not "%EXIT_CODE%"=="0" (
  echo.
  echo Asset generation failed. Exit code: %EXIT_CODE%
  pause
  exit /b %EXIT_CODE%
)

echo.
echo 3D assets generated successfully.
echo Models: %PROJECT_ROOT%\godot\assets\models
echo Preview: %PROJECT_ROOT%\godot\assets\previews\asset_sheet.png
pause
exit /b 0
