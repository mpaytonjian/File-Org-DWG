@echo off
setlocal EnableDelayedExpansion
REM ============================================================
REM   SPF Cleanup launcher (Windows) -- NO PYTHON NEEDED
REM   TIP: you can DRAG the SPF folder onto this .bat file.
REM   It shows a preview first and only moves after you type YES.
REM ============================================================
cd /d "%~dp0"

set "ROOT=%~1"
if "%ROOT%"=="" (
  echo Paste the FULL path to the SPF folder, for example:
  echo   C:\Users\You\Desktop\19. Southern Perfection Fabrication
  echo   ^(or your Egnyte Desktop path^)
  echo.
  set /p ROOT=SPF folder path:
)

echo.
echo ================= PREVIEW (nothing changes) =================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0spf_cleanup.ps1" -Root "%ROOT%"

echo.
echo ============================================================
set /p GO=Type YES to actually move these files (anything else cancels):
if /i not "%GO%"=="YES" (
  echo Cancelled. No changes were made.
  echo.
  pause
  exit /b 0
)

echo.
echo ================= APPLYING MOVES =================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0spf_cleanup.ps1" -Root "%ROOT%" -Apply

echo.
echo Done. A log CSV was written inside "_Archive (Superseded)".
echo Nothing was deleted. Let Egnyte Desktop finish syncing.
echo.
pause
endlocal
