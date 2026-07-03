@echo off
setlocal
REM ============================================================
REM   DWG File Organization -- Windows launcher (SAFE / READ-ONLY)
REM   Double-click this file to scan your Desktop + Documents and
REM   produce a report. It does NOT rename, move, or delete anything.
REM   The report is saved RIGHT HERE, next to this file.
REM ============================================================
cd /d "%~dp0"

echo ============================================================
echo   DWG File Organization -- read-only scan
echo   This ONLY looks at your files and writes a report.
echo   Nothing will be renamed, moved, or deleted.
echo ============================================================
echo.
echo Working folder: %~dp0
echo.

set "PY="
where python  >nul 2>nul && set "PY=python"
if not defined PY where python3 >nul 2>nul && set "PY=python3"

if not defined PY (
  echo ------------------------------------------------------------
  echo   PROBLEM: Python is not installed on this PC.
  echo   That is why no report appeared.
  echo.
  echo   Fix: install it from https://www.python.org/downloads/
  echo   IMPORTANT: on the first install screen, TICK the box
  echo   "Add Python to PATH", then finish and run this file again.
  echo ------------------------------------------------------------
  echo.
  pause
  exit /b 1
)

REM Save the report right next to this launcher (no OneDrive/Desktop guessing).
%PY% scan_inventory.py --out "%~dp0"

echo.
echo ============================================================
echo   DONE. The report was saved in THIS folder:
echo   %~dp0
echo.
echo   Look for a file starting with:
echo   DWG_File_Organization_Test_Report_
echo ============================================================
echo.
echo Want the deeper scan (into subfolders)? Tell Claude.
echo.
pause
endlocal
