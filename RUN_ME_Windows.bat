@echo off
REM ============================================================
REM   DWG File Organization -- Windows launcher (SAFE / READ-ONLY)
REM   Double-click this file to scan your Desktop + Documents and
REM   produce a report. It does NOT rename, move, or delete anything.
REM ============================================================
cd /d "%~dp0"

echo ============================================================
echo   DWG File Organization -- read-only scan
echo   This ONLY looks at your files and writes a report.
echo   Nothing will be renamed, moved, or deleted.
echo ============================================================
echo.

where python >nul 2>nul
if %errorlevel%==0 (
  python scan_inventory.py --out "%USERPROFILE%\Desktop"
) else (
  where python3 >nul 2>nul
  if %errorlevel%==0 (
    python3 scan_inventory.py --out "%USERPROFILE%\Desktop"
  ) else (
    echo Python was not found.
    echo Install it from https://www.python.org/downloads/
    echo During install, TICK "Add Python to PATH". Then run this again.
    echo.
    pause
    exit /b 1
  )
)

echo.
echo Done. Open the report on your Desktop:
echo   DWG_File_Organization_Test_Report_[today's date].md
echo.
echo Want the deeper scan (into subfolders)? Tell Claude and we'll turn it on.
echo.
pause
