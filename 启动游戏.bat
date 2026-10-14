@echo off
setlocal EnableExtensions
title The East - Godot Launcher

set "PROJECT_ROOT=%~dp0"
if "%PROJECT_ROOT:~-1%"=="\" set "PROJECT_ROOT=%PROJECT_ROOT:~0,-1%"
set "GODOT_ROOT=D:\tools\Godot-4.7.2"
set "GODOT_EXE=%GODOT_ROOT%\Godot_v4.7.2-stable_win64.exe"
set "GODOT_CONSOLE=%GODOT_ROOT%\Godot_v4.7.2-stable_win64_console.exe"
set "PROJECT_FILE=%PROJECT_ROOT%\project.godot"
set "GODOT_DATA=%PROJECT_ROOT%\.godot-user"

if not exist "%GODOT_EXE%" (
  echo Godot was not found:
  echo %GODOT_EXE%
  pause
  exit /b 1
)

if not exist "%PROJECT_FILE%" (
  echo Godot project was not found:
  echo %PROJECT_FILE%
  pause
  exit /b 2
)

set "APPDATA=%GODOT_DATA%\AppData\Roaming"
set "LOCALAPPDATA=%GODOT_DATA%\AppData\Local"
set "TEMP=%GODOT_DATA%\Temp"
set "TMP=%GODOT_DATA%\Temp"

if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%"
if not exist "%TEMP%" mkdir "%TEMP%"
if not exist "%GODOT_DATA%\Logs" mkdir "%GODOT_DATA%\Logs"

if /I "%~1"=="check" (
  echo Godot launcher is ready.
  echo Project: %PROJECT_ROOT%
  echo Project file: %PROJECT_FILE%
  echo Engine:  %GODOT_EXE%
  exit /b 0
)

if /I "%~1"=="editor" goto editor
if /I "%~1"=="test" goto test
if /I "%~1"=="render-test" goto render_test

pushd "%PROJECT_ROOT%" || exit /b 3
"%GODOT_EXE%" --path "%PROJECT_ROOT%" --log-file "%GODOT_DATA%\Logs\game.log"
set "EXIT_CODE=%ERRORLEVEL%"
popd
if not "%EXIT_CODE%"=="0" (
  echo.
  echo Godot failed to start. Exit code: %EXIT_CODE%
  echo Log: %GODOT_DATA%\Logs\game.log
  pause
)
exit /b %EXIT_CODE%

:editor
pushd "%PROJECT_ROOT%" || exit /b 3
"%GODOT_EXE%" --editor --path "%PROJECT_ROOT%" --log-file "%GODOT_DATA%\Logs\editor.log"
set "EXIT_CODE=%ERRORLEVEL%"
popd
if not "%EXIT_CODE%"=="0" (
  echo.
  echo Godot editor failed to start. Exit code: %EXIT_CODE%
  echo Log: %GODOT_DATA%\Logs\editor.log
  pause
)
exit /b %EXIT_CODE%

:test
if not exist "%GODOT_CONSOLE%" (
  echo Godot console executable was not found:
  echo %GODOT_CONSOLE%
  exit /b 1
)
pushd "%PROJECT_ROOT%" || exit /b 3
"%GODOT_CONSOLE%" --path "%PROJECT_ROOT%" --headless --quit-after 5 --log-file "%GODOT_DATA%\Logs\launcher-test.log"
set "EXIT_CODE=%ERRORLEVEL%"
popd
if not "%EXIT_CODE%"=="0" (
  echo.
  echo Godot project test failed. Exit code: %EXIT_CODE%
  echo Log: %GODOT_DATA%\Logs\launcher-test.log
  exit /b %EXIT_CODE%
)
pushd "%PROJECT_ROOT%" || exit /b 3
"%GODOT_CONSOLE%" --path "%PROJECT_ROOT%" --headless --script "res://qa/ControlsTimeUiAcceptance.gd" --log-file "%GODOT_DATA%\Logs\launcher-controls-test.log"
set "EXIT_CODE=%ERRORLEVEL%"
popd
if not "%EXIT_CODE%"=="0" (
  echo.
  echo Controls, time, and UI test failed. Exit code: %EXIT_CODE%
  echo Log: %GODOT_DATA%\Logs\launcher-controls-test.log
  exit /b %EXIT_CODE%
)
echo Godot project and controls tests passed.
exit /b 0

:render_test
if not exist "%GODOT_CONSOLE%" (
  echo Godot console executable was not found:
  echo %GODOT_CONSOLE%
  exit /b 1
)
pushd "%PROJECT_ROOT%" || exit /b 3
"%GODOT_CONSOLE%" --path "%PROJECT_ROOT%" --windowed --quit-after 120 --log-file "%GODOT_DATA%\Logs\launcher-render-test.log"
set "EXIT_CODE=%ERRORLEVEL%"
popd
if not "%EXIT_CODE%"=="0" (
  echo.
  echo Godot render test failed. Exit code: %EXIT_CODE%
  echo Log: %GODOT_DATA%\Logs\launcher-render-test.log
  exit /b %EXIT_CODE%
)
echo Godot render test passed.
exit /b 0
