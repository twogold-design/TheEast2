@echo off
setlocal EnableExtensions
title The East - Rebuild Realistic 3D Assets

set "PROJECT_ROOT=%~dp0"
if "%PROJECT_ROOT:~-1%"=="\" set "PROJECT_ROOT=%PROJECT_ROOT:~0,-1%"
set "BLENDER_EXE=D:\tools\blender\setup\blender.exe"
set "GENERATOR=%PROJECT_ROOT%\tools\generate_realistic_assets.py"
set "BLENDER_DATA=%PROJECT_ROOT%\.blender-user"
set "LOG_DIR=%BLENDER_DATA%\Logs"

if not exist "%BLENDER_EXE%" (
  echo Blender was not found:
  echo %BLENDER_EXE%
  pause
  exit /b 1
)

if not exist "%GENERATOR%" (
  echo Realistic asset generator was not found:
  echo %GENERATOR%
  pause
  exit /b 2
)

if /I "%~1"=="check" (
  echo Realistic asset generator is ready.
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
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

pushd "%PROJECT_ROOT%" || exit /b 3
"%BLENDER_EXE%" --background --factory-startup --python "%GENERATOR%" > "%LOG_DIR%\realistic-assets.log" 2>&1
set "EXIT_CODE=%ERRORLEVEL%"
popd

if not "%EXIT_CODE%"=="0" (
  echo.
  echo Realistic asset generation failed. Exit code: %EXIT_CODE%
  echo Log: %LOG_DIR%\realistic-assets.log
  pause
  exit /b %EXIT_CODE%
)

findstr /C:"REALISTIC_FULL_OK 15" "%LOG_DIR%\realistic-assets.log" >nul
if errorlevel 1 (
  echo.
  echo Blender exited without the expected success marker.
  echo Log: %LOG_DIR%\realistic-assets.log
  pause
  exit /b 4
)

echo.
echo Realistic full asset set generated successfully.
echo Models:  %PROJECT_ROOT%\godot\assets\realistic\models
echo Source:  %PROJECT_ROOT%\godot\assets\realistic\source\east_valley_realistic_full.blend
echo Preview: %PROJECT_ROOT%\godot\assets\realistic\previews\realistic_full_asset_sheet.png
pause
exit /b 0
