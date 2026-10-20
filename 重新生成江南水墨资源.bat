@echo off
setlocal EnableExtensions
title The East - Jiangnan Ink Wash Asset Set v4

set "PROJECT_ROOT=%~dp0"
if "%PROJECT_ROOT:~-1%"=="\" set "PROJECT_ROOT=%PROJECT_ROOT:~0,-1%"
set "BLENDER_EXE=D:\tools\blender\setup\blender.exe"
set "GENERATOR=%PROJECT_ROOT%\tools\generate_jiangnan_style_assets_v4.py"
set "BLENDER_DATA=%PROJECT_ROOT%\.blender-user"
set "LOG_DIR=%BLENDER_DATA%\Logs"

if not exist "%BLENDER_EXE%" (
  echo Blender was not found:
  echo %BLENDER_EXE%
  pause
  exit /b 1
)
if not exist "%GENERATOR%" (
  echo Generator was not found:
  echo %GENERATOR%
  pause
  exit /b 2
)
if /I "%~1"=="check" (
  echo Jiangnan v4 generator is ready.
  echo Project: %PROJECT_ROOT%
  echo Blender: %BLENDER_EXE%
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
"%BLENDER_EXE%" --background --factory-startup --python "%GENERATOR%" > "%LOG_DIR%\jiangnan-style-assets-v4.log" 2>&1
set "EXIT_CODE=%ERRORLEVEL%"
popd

if not "%EXIT_CODE%"=="0" (
  echo.
  echo Asset generation failed. Exit code: %EXIT_CODE%
  echo Log: %LOG_DIR%\jiangnan-style-assets-v4.log
  pause
  exit /b %EXIT_CODE%
)
findstr /C:"jiangnan_style_v4_OK 7" "%LOG_DIR%\jiangnan-style-assets-v4.log" >nul
if errorlevel 1 (
  echo.
  echo Blender exited without the expected success marker.
  echo Log: %LOG_DIR%\jiangnan-style-assets-v4.log
  pause
  exit /b 4
)

echo.
echo Jiangnan ink-wash v4 assets generated successfully.
echo Models:  %PROJECT_ROOT%\godot\assets\jiangnan_style_v4\models
echo Source:  %PROJECT_ROOT%\godot\assets\jiangnan_style_v4\source\jiangnan_style_v4_gallery.blend
echo Preview: %PROJECT_ROOT%\godot\assets\jiangnan_style_v4\previews\jiangnan_style_v4_gallery.png
pause
exit /b 0
