@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Advanced Folder Locker with Auto-Lock

:: Pin working directory to where the script file resides
cd /d "%~dp0"

:: ---------------- CONFIGURATION ----------------
set "FOLDER_NAME=Private"
set "CLSID={21EC2020-3AEA-1069-A2DD-08002B30309D}"
set "LOCKER_NAME=ControlPanel.%CLSID%"
set "CONFIG_FILE=.auth.dat"
:: -----------------------------------------------

:: Internal background worker switch
if "%~1"=="--monitor" goto BACKGROUND_MONITOR

:: Check current directory state
if exist "%LOCKER_NAME%" goto UNLOCK_PROMPT
if not exist "%FOLDER_NAME%" goto INITIAL_SETUP

:CONFIRM_LOCK
cls
echo ======================================================
echo                   LOCK DIRECTORY
echo ======================================================
set "cho="
set /p "cho=Are you sure you want to lock '%FOLDER_NAME%'? (Y/N): "
if /i "%cho%"=="Y" goto DO_LOCK
if /i "%cho%"=="N" goto EXIT_SCRIPT
echo Invalid selection.
timeout /t 1 >nul
goto CONFIRM_LOCK

:DO_LOCK
echo.
echo Locking directory...

:: 1. Rename to CLSID disguise with retry mechanism
set /a RETRY_COUNT=0
:RETRY_MANUAL_RENAME
ren "%FOLDER_NAME%" "%LOCKER_NAME%" 2>nul
if not errorlevel 1 goto MANUAL_RENAME_SUCCESS

set /a RETRY_COUNT+=1
if %RETRY_COUNT% LSS 3 (
    timeout /t 2 /nobreak >nul
    goto RETRY_MANUAL_RENAME
)

echo Error: Could not rename directory. Close all files inside it first.
powershell -NoProfile -Command "[void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms'); [System.Media.SystemSounds]::Hand.Play(); $notify = New-Object System.Windows.Forms.NotifyIcon; $notify.Icon = [System.Drawing.SystemIcons]::Error; $notify.BalloonTipTitle = 'Folder Locker Failed'; $notify.BalloonTipText = 'Could not lock folder. Please close all open files inside %FOLDER_NAME%.'; $notify.BalloonTipIcon = 'Error'; $notify.Visible = $true; $notify.ShowBalloonTip(4000); Start-Sleep -Milliseconds 600; $notify.Dispose()" >nul 2>&1
pause
goto EXIT_SCRIPT

:MANUAL_RENAME_SUCCESS
attrib +h +s "%LOCKER_NAME%" >nul 2>&1
icacls "%LOCKER_NAME%" /deny "%USERNAME%":(OI)(CI)(F) >nul 2>&1

echo Directory locked successfully.
timeout /t 2 >nul
goto EXIT_SCRIPT

:UNLOCK_PROMPT
if not exist "%CONFIG_FILE%" (
    echo Critical Error: Missing configuration data [%CONFIG_FILE%].
    pause
    goto EXIT_SCRIPT
)

:: Read configuration lines (Line 1: SHA-256 hash, Line 2: Idle timeout in minutes)
set "STORED_HASH="
set "STORED_TIMEOUT="
< "%CONFIG_FILE%" (
    set /p "STORED_HASH="
    set /p "STORED_TIMEOUT="
)

if "%STORED_TIMEOUT%"=="" set "STORED_TIMEOUT=5"
set "ATTEMPTS=0"

:UNLOCK_LOOP
cls
echo ======================================================
echo                  UNLOCK DIRECTORY
echo ======================================================
echo Remaining attempts: !ATTEMPTS!/3

:: Prompt for password
set "INPUT_PASS="
set /p "INPUT_PASS=Enter password: "

if "!INPUT_PASS!"=="" (
    echo Password cannot be empty.
    timeout /t 1 >nul
    goto UNLOCK_LOOP
)

:: Compute SHA-256 hash natively via certutil
set "TMP_INPUT=%TEMP%\__pwd_%RANDOM%.txt"
set "TMP_HASH=%TEMP%\__hash_%RANDOM%.txt"

<nul set /p="!INPUT_PASS!">"%TMP_INPUT%"
certutil -hashfile "%TMP_INPUT%" SHA256 > "%TMP_HASH%" 2>nul

set "COMPUTED_HASH="
for /f "skip=1 tokens=*" %%A in ('type "%TMP_HASH%"') do (
    if not defined COMPUTED_HASH (
        set "COMPUTED_HASH=%%A"
        set "COMPUTED_HASH=!COMPUTED_HASH: =!"
    )
)

del /f /q "%TMP_INPUT%" "%TMP_HASH%" >nul 2>&1

:: Verify password match
if /i "!COMPUTED_HASH!"=="!STORED_HASH!" goto UNLOCK_SUCCESS

:: Failed attempt handling
set /a ATTEMPTS+=1
if !ATTEMPTS! GEQ 3 goto LOCKOUT_HALT

:: Calculate exponential throttle delay: 2 sec on fail 1, 4 sec on fail 2
set /a DELAY=2 * !ATTEMPTS!
echo.
echo [!] Incorrect password. Penalty delay of !DELAY! seconds applied.
timeout /t !DELAY! /nobreak >nul
goto UNLOCK_LOOP

:LOCKOUT_HALT
echo.
echo [!] Maximum failed attempts reached. Access locked out.
powershell -NoProfile -Command "[void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms'); [System.Media.SystemSounds]::Hand.Play(); $notify = New-Object System.Windows.Forms.NotifyIcon; $notify.Icon = [System.Drawing.SystemIcons]::Error; $notify.BalloonTipTitle = 'Folder Locker'; $notify.BalloonTipText = 'Too many failed unlock attempts.'; $notify.BalloonTipIcon = 'Error'; $notify.Visible = $true; $notify.ShowBalloonTip(4000); Start-Sleep -Milliseconds 600; $notify.Dispose()" >nul 2>&1
pause
goto EXIT_SCRIPT

:UNLOCK_SUCCESS
:: Restore permissions and remove attributes
icacls "%LOCKER_NAME%" /remove:d "%USERNAME%" >nul 2>&1
attrib -h -s "%LOCKER_NAME%" >nul 2>&1
ren "%LOCKER_NAME%" "%FOLDER_NAME%" 2>nul

if errorlevel 1 (
    echo Error: Could not restore directory name. Check permissions.
    pause
    goto EXIT_SCRIPT
)

echo Directory unlocked successfully.

:: Launch persistent, low-overhead background monitor
if !STORED_TIMEOUT! GTR 0 (
    echo Auto-lock active: Will lock after !STORED_TIMEOUT! minute(s) of inactivity.
    start "" /b cmd.exe /c ""%~f0" --monitor !STORED_TIMEOUT!"
)

timeout /t 2 >nul
goto EXIT_SCRIPT

:INITIAL_SETUP
cls
echo ======================================================
echo                  INITIAL SETUP
echo ======================================================
echo Creating folder '%FOLDER_NAME%'...
md "%FOLDER_NAME%" 2>nul

echo.
echo 1. Set your master password:
set "NEW_PASS="
set /p "NEW_PASS=Password: "

if "!NEW_PASS!"=="" (
    echo Password cannot be empty.
    pause
    goto EXIT_SCRIPT
)

:: Hash the password
set "TMP_INPUT=%TEMP%\__pwd_%RANDOM%.txt"
set "TMP_HASH=%TEMP%\__hash_%RANDOM%.txt"

<nul set /p="!NEW_PASS!">"%TMP_INPUT%"
certutil -hashfile "%TMP_INPUT%" SHA256 > "%TMP_HASH%" 2>nul

set "NEW_HASH="
for /f "skip=1 tokens=*" %%A in ('type "%TMP_HASH%"') do (
    if not defined NEW_HASH (
        set "NEW_HASH=%%A"
        set "NEW_HASH=!NEW_HASH: =!"
    )
)
del /f /q "%TMP_INPUT%" "%TMP_HASH%" >nul 2>&1

:PROMPT_TIMEOUT
echo.
echo 2. Set auto-lock idle timeout:
echo (Enter idle minutes before auto-locking, or 0 to disable)
set "USER_TIMEOUT="
set /p "USER_TIMEOUT=Timeout (e.g. 5): "

:: Validate numeric input
echo !USER_TIMEOUT!| findstr /r "^[0-9][0-9]*$" >nul
if errorlevel 1 (
    echo Please enter a valid number.
    goto PROMPT_TIMEOUT
)

:: Save hash and timeout to configuration file
(
    echo !NEW_HASH!
    echo !USER_TIMEOUT!
) > "%CONFIG_FILE%"

attrib +h +s "%CONFIG_FILE%" >nul 2>&1

echo.
echo Setup complete. Folder created and settings stored.
pause
goto EXIT_SCRIPT

:BACKGROUND_MONITOR
set "TARGET_MINUTES=%~2"
if "%TARGET_MINUTES%"=="" set "TARGET_MINUTES=5"
if %TARGET_MINUTES% LEQ 0 exit /b

:: Single persistent PowerShell monitor: zero CPU thrashing, event-driven filesystem watcher
powershell -NoProfile -ExecutionPolicy Bypass -Command "& {
    $targetDir = Join-Path '%~dp0' '%FOLDER_NAME%';
    $lockerDir = Join-Path '%~dp0' '%LOCKER_NAME%';
    $targetMs = [uint32](%TARGET_MINUTES% * 60 * 1000);
    $currentUser = $env:USERNAME;

    Add-Type @'
    using System;
    using System.Runtime.InteropServices;
    public class Win32Input {
        [DllImport(\"user32.dll\")] public static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);
        [StructLayout(LayoutKind.Sequential)] public struct LASTINPUTINFO {
            public uint cbSize;
            public uint dwTime;
        }
        public static uint GetIdleMilliseconds() {
            LASTINPUTINFO lii = new LASTINPUTINFO();
            lii.cbSize = (uint)Marshal.SizeOf(lii);
            GetLastInputInfo(ref lii);
            return ((uint)Environment.TickCount - lii.dwTime);
        }
    }
'@;

    # Track directory I/O via native events instead of disk crawl
    $script:lastIo = [DateTime]::UtcNow;
    $watcher = New-Object System.IO.FileSystemWatcher;
    $watcher.Path = $targetDir;
    $watcher.IncludeSubdirectories = $true;
    $watcher.EnableRaisingEvents = $true;

    $action = { $script:lastIo = [DateTime]::UtcNow };
    $handlers = @(
        (Register-ObjectEvent $watcher 'Changed' -Action $action),
        (Register-ObjectEvent $watcher 'Created' -Action $action),
        (Register-ObjectEvent $watcher 'Deleted' -Action $action),
        (Register-ObjectEvent $watcher 'Renamed' -Action $action)
    );

    try {
        while ($true) {
            Start-Sleep -Seconds 5;

            if (-not (Test-Path -LiteralPath $targetDir)) { break; }

            $idleMs = [Win32Input]::GetIdleMilliseconds();
            $timeSinceIoMs = ([DateTime]::UtcNow - $script:lastIo).TotalMilliseconds;

            if (($idleMs -ge $targetMs) -and ($timeSinceIoMs -ge $targetMs)) {
                $renamed = $false;
                for ($i = 0; $i -lt 3; $i++) {
                    try {
                        Rename-Item -LiteralPath $targetDir -NewName '%LOCKER_NAME%' -ErrorAction Stop;
                        $renamed = $true;
                        break;
                    } catch {
                        Start-Sleep -Seconds 2;
                    }
                }

                if (-not $renamed) {
                    [void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms');
                    [System.Media.SystemSounds]::Hand.Play();
                    $notify = New-Object System.Windows.Forms.NotifyIcon;
                    $notify.Icon = [System.Drawing.SystemIcons]::Error;
                    $notify.BalloonTipTitle = 'Folder Locker Failed';
                    $notify.BalloonTipText = 'Could not lock folder. Please close all open files inside %FOLDER_NAME%.';
                    $notify.BalloonTipIcon = 'Error';
                    $notify.Visible = $true;
                    $notify.ShowBalloonTip(4000);
                    Start-Sleep -Milliseconds 600;
                    $notify.Dispose();
                    break;
                }

                # Apply hidden/system and deny permissions
                & attrib +h +s $lockerDir 2>$null;
                & icacls $lockerDir /deny ${currentUser}:'(OI)(CI)(F)' 2>$null;

                # Notify user of lock
                [void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms');
                [System.Media.SystemSounds]::Exclamation.Play();
                $notify = New-Object System.Windows.Forms.NotifyIcon;
                $notify.Icon = [System.Drawing.SystemIcons]::Warning;
                $notify.BalloonTipTitle = 'Folder Locker';
                $notify.BalloonTipText = 'Private folder locked due to inactivity.';
                $notify.BalloonTipIcon = 'Warning';
                $notify.Visible = $true;
                $notify.ShowBalloonTip(4000);
                Start-Sleep -Milliseconds 600;
                $notify.Dispose();
                break;
            }
        }
    } finally {
        $watcher.EnableRaisingEvents = $false;
        $watcher.Dispose();
        foreach ($h in $handlers) { Unregister-Event -SourceIdentifier $h.Name -ErrorAction SilentlyContinue; }
    }
}"
exit /b

:EXIT_SCRIPT
endlocal