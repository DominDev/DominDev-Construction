@echo off
REM Claude-Mem Worker Service - Universal Control Script
REM Usage: claude-mem.bat [start|stop|restart|status]
REM Created: 2026-01-09

setlocal enabledelayedexpansion

REM Define paths
set "WORKER_SCRIPT=C:\Users\pdomi\.claude\plugins\cache\thedotmack\claude-mem\9.0.1\scripts\worker-cli.js"
set "LOG_DIR=C:\Users\pdomi\.claude-mem\logs"

REM Parse command
set "COMMAND=%~1"

REM If no command provided, show menu
if "%COMMAND%"=="" goto :MENU

REM Execute command
if /i "%COMMAND%"=="start" goto :START
if /i "%COMMAND%"=="stop" goto :STOP
if /i "%COMMAND%"=="restart" goto :RESTART
if /i "%COMMAND%"=="status" goto :STATUS
if /i "%COMMAND%"=="help" goto :HELP

echo [ERROR] Unknown command: %COMMAND%
goto :HELP

:MENU
cls
echo.
echo ============================================
echo    Claude-Mem Worker Service Control
echo ============================================
echo.
echo Current status:
netstat -ano | findstr :37777 | findstr LISTENING >nul 2>&1
if %errorlevel% equ 0 (
    echo [RUNNING] Worker is active on port 37777
    echo Dashboard: http://localhost:37777
) else (
    echo [STOPPED] Worker is not running
)
echo.
echo ============================================
echo.
echo Select action:
echo.
echo   1. Start worker
echo   2. Stop worker
echo   3. Restart worker
echo   4. Show status
echo   5. View logs
echo   6. Exit
echo.
set /p "CHOICE=Enter choice (1-6): "

if "%CHOICE%"=="1" goto :START
if "%CHOICE%"=="2" goto :STOP
if "%CHOICE%"=="3" goto :RESTART
if "%CHOICE%"=="4" goto :STATUS
if "%CHOICE%"=="5" goto :LOGS
if "%CHOICE%"=="6" goto :EOF

echo [ERROR] Invalid choice
timeout /t 2 /nobreak >nul
goto :MENU

:START
echo.
echo [INFO] Starting worker service...
echo.

REM Check if already running (LISTENING state only)
netstat -ano | findstr :37777 | findstr LISTENING >nul 2>&1
if %errorlevel% equ 0 (
    echo [INFO] Worker is already running on port 37777
    echo Dashboard: http://localhost:37777
    goto :END
)

REM Start worker in background
start /B node "%WORKER_SCRIPT%" start >nul 2>&1

REM Wait and verify
echo Waiting for worker to start...
timeout /t 5 /nobreak >nul

netstat -ano | findstr :37777 | findstr LISTENING >nul 2>&1
if %errorlevel% equ 0 (
    echo.
    echo [SUCCESS] Worker started successfully!
    echo Dashboard: http://localhost:37777
    echo.
) else (
    echo.
    echo [ERROR] Failed to start worker
    echo.
    echo Check logs: %LOG_DIR%
    echo Latest log:
    for /f "delims=" %%F in ('dir /b /o-d "%LOG_DIR%\*.log" 2^>nul') do (
        powershell -Command "Get-Content '%LOG_DIR%\%%F' -Tail 5"
        goto :START_END
    )
    :START_END
)
goto :END

:STOP
echo.
echo [INFO] Stopping worker service...
echo.

REM Stop worker
node "%WORKER_SCRIPT%" stop

REM Wait and verify
timeout /t 2 /nobreak >nul
netstat -ano | findstr :37777 >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [SUCCESS] Worker stopped successfully!
) else (
    echo.
    echo [WARNING] Worker may still be running
)
goto :END

:RESTART
echo.
echo [INFO] Restarting worker service...
echo.

REM Stop first
call :STOP
timeout /t 2 /nobreak >nul

REM Then start
call :START
goto :END

:STATUS
cls
echo.
echo ============================================
echo    Claude-Mem Worker Service Status
echo ============================================
echo.

REM Check port (LISTENING only)
netstat -ano | findstr :37777 | findstr LISTENING >nul 2>&1
if %errorlevel% equ 0 (
    echo [STATUS] Worker is RUNNING
    echo.
    echo Port: 37777
    echo Dashboard: http://localhost:37777
    echo.
    echo Process details:
    for /f "tokens=5" %%a in ('netstat -ano ^| findstr :37777 ^| findstr LISTENING') do (
        echo PID: %%a
    )
    echo.
    netstat -ano | findstr :37777
) else (
    echo [STATUS] Worker is NOT RUNNING
    echo.
    echo To start: claude-mem.bat start
)

echo.
echo ============================================
echo Recent logs:
echo ============================================
echo.

REM Find latest log file
for /f "delims=" %%F in ('dir /b /o-d "%LOG_DIR%\*.log" 2^>nul') do (
    set "LATEST_LOG=%LOG_DIR%\%%F"
    goto :SHOW_LOG
)

:SHOW_LOG
if exist "%LATEST_LOG%" (
    echo Log file: %LATEST_LOG%
    echo.
    powershell -Command "Get-Content '%LATEST_LOG%' -Tail 10"
) else (
    echo No logs found in %LOG_DIR%
)
goto :END

:LOGS
cls
echo.
echo ============================================
echo    Claude-Mem Worker Logs
echo ============================================
echo.

REM Find latest log file
for /f "delims=" %%F in ('dir /b /o-d "%LOG_DIR%\*.log" 2^>nul') do (
    set "LATEST_LOG=%LOG_DIR%\%%F"
    goto :SHOW_FULL_LOG
)

:SHOW_FULL_LOG
if exist "%LATEST_LOG%" (
    echo Log file: %LATEST_LOG%
    echo.
    type "%LATEST_LOG%"
    echo.
    echo.
    echo [Press any key to return to menu]
    pause >nul
    goto :MENU
) else (
    echo No logs found in %LOG_DIR%
    timeout /t 3 /nobreak >nul
    goto :MENU
)

:HELP
echo.
echo Usage: claude-mem.bat [command]
echo.
echo Commands:
echo   start     - Start worker service
echo   stop      - Stop worker service
echo   restart   - Restart worker service
echo   status    - Show current status and logs
echo   help      - Show this help message
echo.
echo If no command is provided, interactive menu will be shown.
echo.
goto :END

:END
if "%COMMAND%"=="" (
    echo.
    pause
    goto :MENU
) else (
    echo.
    if not "%1"=="" pause
)
endlocal
