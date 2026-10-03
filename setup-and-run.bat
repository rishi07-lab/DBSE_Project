@echo off
title CarePulse HMS - Setup and Run
cd /d "%~dp0"

echo [1/4] Installing backend packages...
cd backend
if not exist node_modules ( call npm install || goto :error )

echo [2/4] Applying schema changes and adding demo data to hospital_management...
call npm run db:seed || goto :error

echo [3/4] Starting backend (gateway on http://localhost:5000)...
start "CarePulse Backend" cmd /k "npm start"
cd ..

echo [4/4] Starting frontend...
cd DBSE_Project
call start.bat
exit /b 0

:error
echo.
echo [ERROR] Something failed. Check that MySQL is running on port 3306 and backend\.env has the right password.
pause
exit /b 1
