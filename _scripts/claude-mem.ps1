#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Claude-Mem Worker Service Control Script

.DESCRIPTION
    Universal script for managing claude-mem worker service.
    Works in PowerShell, Git Bash, CMD, and all terminal types.

.PARAMETER Command
    Action to perform: start, stop, restart, status, help
    If omitted, shows interactive menu.

.EXAMPLE
    ./claude-mem.ps1 start
    ./claude-mem.ps1 status
    ./claude-mem.ps1

.NOTES
    Created: 2026-01-09
#>

param(
    [Parameter(Position=0)]
    [ValidateSet('start','stop','restart','status','help','')]
    [string]$Command = ''
)

# Configuration
$WorkerScript = "C:\Users\pdomi\.claude\plugins\cache\thedotmack\claude-mem\9.0.1\scripts\worker-cli.js"
$LogDir = "C:\Users\pdomi\.claude-mem\logs"

# Color support check
# Disable colors if running through Git Bash (ANSI codes don't render properly)
$SupportsColor = $Host.UI.SupportsVirtualTerminal -and (-not $env:MSYSTEM)

# Helper functions
function Write-ColorText {
    param([string]$Text, [string]$Color = 'White')

    if ($SupportsColor) {
        $colors = @{
            'Red' = "`e[31m"
            'Green' = "`e[32m"
            'Yellow' = "`e[33m"
            'Blue' = "`e[34m"
            'Cyan' = "`e[36m"
            'White' = "`e[37m"
            'Reset' = "`e[0m"
        }
        Write-Host "$($colors[$Color])$Text$($colors['Reset'])"
    } else {
        Write-Host $Text
    }
}

function Test-WorkerRunning {
    $listening = netstat -ano | Select-String ':37777' | Select-String 'LISTENING'
    return $null -ne $listening
}

function Get-WorkerPID {
    $result = netstat -ano | Select-String ':37777' | Select-String 'LISTENING'
    if ($result) {
        $parts = $result -split '\s+' | Where-Object { $_ }
        return $parts[-1]
    }
    return $null
}

function Show-Menu {
    Clear-Host
    Write-Host ""
    Write-Host "============================================"
    Write-Host "   Claude-Mem Worker Service Control"
    Write-Host "============================================"
    Write-Host ""
    Write-Host "Current status:"

    if (Test-WorkerRunning) {
        Write-ColorText "[RUNNING] Worker is active on port 37777" 'Green'
        Write-Host "Dashboard: http://localhost:37777"
    } else {
        Write-ColorText "[STOPPED] Worker is not running" 'Red'
    }

    Write-Host ""
    Write-Host "============================================"
    Write-Host ""
    Write-Host "Select action:"
    Write-Host ""
    Write-Host "  1. Start worker"
    Write-Host "  2. Stop worker"
    Write-Host "  3. Restart worker"
    Write-Host "  4. Show status"
    Write-Host "  5. View logs"
    Write-Host "  6. Exit"
    Write-Host ""

    $choice = Read-Host "Enter choice (1-6)"

    switch ($choice) {
        '1' { Start-Worker; Show-Menu }
        '2' { Stop-Worker; Show-Menu }
        '3' { Restart-Worker; Show-Menu }
        '4' { Show-Status; Read-Host "Press Enter to continue"; Show-Menu }
        '5' { Show-Logs; Read-Host "Press Enter to continue"; Show-Menu }
        '6' { return }
        default {
            Write-ColorText "[ERROR] Invalid choice" 'Red'
            Start-Sleep -Seconds 2
            Show-Menu
        }
    }
}

function Start-Worker {
    Write-Host ""
    Write-ColorText "[INFO] Starting worker service..." 'Cyan'
    Write-Host ""

    # Check if already running
    if (Test-WorkerRunning) {
        Write-ColorText "[INFO] Worker is already running on port 37777" 'Yellow'
        Write-Host "Dashboard: http://localhost:37777"
        return
    }

    # Start worker in background
    Write-Host "Waiting for worker to start..."
    $job = Start-Job -ScriptBlock {
        param($script)
        node $script start
    } -ArgumentList $WorkerScript

    # Wait up to 10 seconds for worker to start
    $timeout = 10
    $elapsed = 0
    while ($elapsed -lt $timeout) {
        Start-Sleep -Seconds 1
        $elapsed++

        if (Test-WorkerRunning) {
            Write-Host ""
            Write-ColorText "[SUCCESS] Worker started successfully!" 'Green'
            Write-Host "Dashboard: http://localhost:37777"
            Write-Host ""
            return
        }
    }

    Write-Host ""
    Write-ColorText "[ERROR] Failed to start worker" 'Red'
    Write-Host ""
    Write-Host "Check logs: $LogDir"

    # Show last 5 lines of latest log
    $latestLog = Get-ChildItem $LogDir -Filter "*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latestLog) {
        Write-Host ""
        Write-Host "Latest log entries:"
        Get-Content $latestLog.FullName -Tail 5
    }
}

function Stop-Worker {
    Write-Host ""
    Write-ColorText "[INFO] Stopping worker service..." 'Cyan'
    Write-Host ""

    node $WorkerScript stop | Out-Null

    Start-Sleep -Seconds 2

    if (-not (Test-WorkerRunning)) {
        Write-Host ""
        Write-ColorText "[SUCCESS] Worker stopped successfully!" 'Green'
        Write-Host ""
    } else {
        Write-Host ""
        Write-ColorText "[WARNING] Worker may still be running" 'Yellow'
        Write-Host ""
    }
}

function Restart-Worker {
    Write-Host ""
    Write-ColorText "[INFO] Restarting worker service..." 'Cyan'
    Write-Host ""

    Stop-Worker
    Start-Sleep -Seconds 2
    Start-Worker
}

function Show-Status {
    Clear-Host
    Write-Host ""
    Write-Host "============================================"
    Write-Host "   Claude-Mem Worker Service Status"
    Write-Host "============================================"
    Write-Host ""

    if (Test-WorkerRunning) {
        Write-ColorText "[STATUS] Worker is RUNNING" 'Green'
        Write-Host ""
        Write-Host "Port: 37777"
        Write-Host "Dashboard: http://localhost:37777"
        Write-Host ""

        $WorkerPID = Get-WorkerPID
        if ($WorkerPID) {
            Write-Host "Process details:"
            Write-Host "PID: $WorkerPID"
        }

        Write-Host ""
        netstat -ano | Select-String ':37777'
    } else {
        Write-ColorText "[STATUS] Worker is NOT RUNNING" 'Red'
        Write-Host ""
        Write-Host "To start: claude-mem start"
    }

    Write-Host ""
    Write-Host "============================================"
    Write-Host "Recent logs:"
    Write-Host "============================================"
    Write-Host ""

    $latestLog = Get-ChildItem $LogDir -Filter "*.log" -ErrorAction SilentlyContinue |
                 Sort-Object LastWriteTime -Descending |
                 Select-Object -First 1

    if ($latestLog) {
        Write-Host "Log file: $($latestLog.FullName)"
        Write-Host ""

        # Use tail in Git Bash for proper UTF-8 display, PowerShell Get-Content otherwise
        if ($env:MSYSTEM) {
            # Git Bash - use tail for proper UTF-8
            $unixPath = $latestLog.FullName -replace '\\', '/' -replace '^([A-Z]):', '/$1'
            & bash -c "tail -n 10 '$unixPath'"
        } else {
            # Native PowerShell
            Get-Content $latestLog.FullName -Tail 10
        }
    } else {
        Write-Host "No logs found in $LogDir"
    }
}

function Show-Logs {
    Clear-Host
    Write-Host ""
    Write-Host "============================================"
    Write-Host "   Claude-Mem Worker Logs"
    Write-Host "============================================"
    Write-Host ""

    $latestLog = Get-ChildItem $LogDir -Filter "*.log" -ErrorAction SilentlyContinue |
                 Sort-Object LastWriteTime -Descending |
                 Select-Object -First 1

    if ($latestLog) {
        Write-Host "Log file: $($latestLog.FullName)"
        Write-Host ""

        # Use cat in Git Bash for proper UTF-8 display, PowerShell Get-Content otherwise
        if ($env:MSYSTEM) {
            # Git Bash - use cat for proper UTF-8
            $unixPath = $latestLog.FullName -replace '\\', '/' -replace '^([A-Z]):', '/$1'
            & bash -c "cat '$unixPath'"
        } else {
            # Native PowerShell
            Get-Content $latestLog.FullName
        }
    } else {
        Write-Host "No logs found in $LogDir"
    }
}

function Show-Help {
    Write-Host ""
    Write-Host "Usage: claude-mem [command]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  start     - Start worker service"
    Write-Host "  stop      - Stop worker service"
    Write-Host "  restart   - Restart worker service"
    Write-Host "  status    - Show current status and logs"
    Write-Host "  help      - Show this help message"
    Write-Host ""
    Write-Host "If no command is provided, interactive menu will be shown."
    Write-Host ""
}

# Main execution
switch ($Command) {
    'start'   { Start-Worker }
    'stop'    { Stop-Worker }
    'restart' { Restart-Worker }
    'status'  { Show-Status }
    'help'    { Show-Help }
    default   { Show-Menu }
}
