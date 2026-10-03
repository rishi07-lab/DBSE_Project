@echo off
title CarePulse Hospital Management System
echo ========================================================
echo   CarePulse Hospital Management System (Frontend)
echo ========================================================
echo.
cd /d "%~dp0"

REM Check if node_modules exists
if not exist "node_modules\" (
    echo [1/2] Installing required packages with npm...
    call npm install
    if errorlevel 1 (
        echo.
        echo [ERROR] Failed to install npm dependencies. Make sure Node.js is installed.
        pause
        exit /b %errorlevel%
    )
    echo [1/2] Packages installed successfully!
    echo.
) else (
    echo [1/2] Packages already installed.
    echo.
)

echo [2/2] Launching React + Vite local development server...
echo The app will open in your default browser at http://localhost:5173
echo Press Ctrl+C in this window anytime to stop the server.
echo.

REM Open default browser
start http://localhost:5173

REM Run Vite
call npm run dev

pause
