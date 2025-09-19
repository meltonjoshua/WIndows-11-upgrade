@echo off
REM Windows 11 Silent Upgrade - Batch Wrapper
REM This batch file provides an easy way to run the PowerShell script with proper execution policy

echo Windows 11 Silent Upgrade Script
echo ================================
echo.

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script must be run as Administrator!
    echo Right-click and select "Run as administrator"
    pause
    exit /b 1
)

echo Running Windows 11 Silent Upgrade...
echo.

REM Set execution policy temporarily and run the PowerShell script
powershell.exe -ExecutionPolicy Bypass -File "%~dp0Windows11-Silent-Upgrade.ps1" %*

REM Check the exit code
if %errorLevel% equ 0 (
    echo.
    echo Upgrade process completed successfully!
) else (
    echo.
    echo Upgrade process failed with error code: %errorLevel%
    echo Check the log files for more details.
)

echo.
pause