@echo off
setlocal
REM ============================================================
REM   DWG File Organization -- SORTER (NO PYTHON NEEDED)
REM   Builds your Deal-first structure into a NEW COPY folder on
REM   your Desktop: "DWG Organized (Copy - Safe)".
REM   Your ORIGINAL files are NEVER touched. Fully reversible.
REM ============================================================
cd /d "%~dp0"

echo ============================================================
echo   DWG File Organization -- SORTER (safe copy mode)
echo.
echo   This COPIES your Desktop + Documents + Downloads files into a
echo   new, organized folder on your Desktop. It does NOT move,
echo   rename, or delete any of your original files.
echo ============================================================
echo.
pause

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0organize_windows.ps1"

echo.
echo When it finishes, open this folder on your Desktop:
echo   DWG Organized (Copy - Safe)
echo.
echo Review it. If you like it, tell Claude and we can talk about
echo doing the real move. If not, just delete that folder -- your
echo originals are untouched.
echo.
pause
endlocal
