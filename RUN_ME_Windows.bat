@echo off
setlocal
REM ============================================================
REM   DWG File Organization -- Windows launcher (NO PYTHON NEEDED)
REM   READ-ONLY. Scans Desktop + Documents + Downloads and writes ONE
REM   report into THIS folder. Does NOT rename, move, or delete anything.
REM ============================================================
cd /d "%~dp0"

echo ============================================================
echo   DWG File Organization -- read-only scan (no Python needed)
echo   This ONLY looks at your files and writes a report.
echo   Nothing will be renamed, moved, or deleted.
echo ============================================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scan_windows.ps1"

echo.
echo The report is the file starting with:
echo   DWG_File_Organization_Test_Report_
echo in THIS folder:  %~dp0
echo.
pause
endlocal
