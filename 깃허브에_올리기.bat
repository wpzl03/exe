@echo off
cd /d "%~dp0"
set GCM_GUI_PROMPT=0
set GCM_INTERACTIVE=always
echo ============================================================
echo  Uploading to GitHub (wpzl03/exe)
echo.
echo  1. The page github.com/login/device will open in your browser.
echo  2. Type the 8-character code shown below (ex: ABCD-1234).
echo  3. Click Authorize. The upload continues automatically.
echo ============================================================
echo.
start "" https://github.com/login/device
"C:\Program Files\Git\cmd\git.exe" -c credential.gitHubAuthModes=device push -u origin main
echo.
echo ============================================================
echo  If you see "main -> main" above, it worked!
echo ============================================================
pause
