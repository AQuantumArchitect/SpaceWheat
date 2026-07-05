@echo off
setlocal EnableExtensions

set "PROJECT_ROOT=%PROJECT_ROOT%"
if "%PROJECT_ROOT%"=="" (
  echo [windows_rig] PROJECT_ROOT is required
  exit /b 2
)

set "GODOT_WINDOWS_PATH=%GODOT_WINDOWS_PATH%"
if "%GODOT_WINDOWS_PATH%"=="" (
  echo [windows_rig] GODOT_WINDOWS_PATH is required ^(path to godot .exe^)
  exit /b 2
)

set "PROJECT_ROOT_WIN=%PROJECT_ROOT_WIN%"
if "%PROJECT_ROOT_WIN%"=="" (
  echo [windows_rig] PROJECT_ROOT_WIN is required
  exit /b 2
)

set "RIG_RENDERING_DRIVER=%RIG_RENDERING_DRIVER%"
set "RIG_DISPLAY_MODE=%RIG_DISPLAY_MODE%"
if "%RIG_DISPLAY_MODE%"=="" set "RIG_DISPLAY_MODE=headless"

set "RIG_QUEUE_PATH=%RIG_QUEUE_PATH%"
set "RIG_RESULT_PATH=%RIG_RESULT_PATH%"
set "RIG_BRIDGE_SENTINEL_PATH=%RIG_BRIDGE_SENTINEL_PATH%"
set "RIG_HEARTBEAT_PATH=%RIG_HEARTBEAT_PATH%"

if not "%RIG_QUEUE_PATH%"=="" (
  for %%I in ("%RIG_QUEUE_PATH%") do if not exist "%%~dpI" mkdir "%%~dpI"
  break> "%RIG_QUEUE_PATH%"
)

echo [windows_rig] project=%PROJECT_ROOT_WIN%
echo [windows_rig] godot=%GODOT_WINDOWS_PATH%
echo [windows_rig] display=%RIG_DISPLAY_MODE%

if /I "%RIG_DISPLAY_MODE%"=="headless" (
  start "" /B "%GODOT_WINDOWS_PATH%" --headless --path "%PROJECT_ROOT_WIN%" --script 🍄/🎛️/rig_listener.gd
  exit /b %ERRORLEVEL%
)

if not "%RIG_RENDERING_DRIVER%"=="" (
  start "" /B "%GODOT_WINDOWS_PATH%" --rendering-driver "%RIG_RENDERING_DRIVER%" --path "%PROJECT_ROOT_WIN%" --script 🍄/🎛️/rig_listener.gd
  exit /b %ERRORLEVEL%
)

start "" /B "%GODOT_WINDOWS_PATH%" --path "%PROJECT_ROOT_WIN%" --script 🍄/🎛️/rig_listener.gd
exit /b %ERRORLEVEL%
