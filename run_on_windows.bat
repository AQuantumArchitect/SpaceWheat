@echo off
REM Run SpaceWheat on Windows native Godot with OpenGL3
REM This avoids WSL Vulkan issues entirely

echo Starting Godot (Windows native) with OpenGL3 renderer...
echo.

REM Replace this path with your actual Godot install location
REM Example: C:\Godot\Godot_v4.5-stable_win64.exe
set GODOT_PATH="C:\Godot\godot.exe"

REM Project path via WSL mount
set PROJECT_PATH="\\wsl.localhost\Ubuntu\home\tehcr33d\ws\SpaceWheat"

REM Launch with OpenGL3 (avoids Vulkan issues on old GPU)
%GODOT_PATH% --rendering-driver opengl3 --path %PROJECT_PATH% VisualBubbleTest.tscn

pause
