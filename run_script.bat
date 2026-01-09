@echo off
chcp 65001 >nul
color 0A
title PowerShell Script Launcher

:MENU
cls
echo ========================================
echo       PowerShell Script Launcher
echo ========================================
echo.
echo Select a script to run:
echo.
echo [1] get_information.ps1  - System Information Report
echo [2] get_performance.ps1  - Performance Check
echo.
echo [0] Exit
echo.
echo ========================================
echo.

set /p choice="Enter your choice (0-2): "

if "%choice%"=="1" goto RUN_INFO
if "%choice%"=="2" goto RUN_PERF
if "%choice%"=="0" goto EXIT
timeout /t 2 >nul
goto MENU

:RUN_INFO
cls
echo ========================================
echo      Running: get_information.ps1
echo ========================================
echo.
PowerShell -ExecutionPolicy Bypass -File "%~dp0get_information.ps1"
echo.
pause
goto MENU

:RUN_PERF
cls
echo ========================================
echo      Running: get_performance.ps1
echo ========================================
echo.
PowerShell -ExecutionPolicy Bypass -File "%~dp0get_performance.ps1"
echo.
pause
goto MENU

:EXIT
exit