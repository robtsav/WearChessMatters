@echo off
setlocal EnableDelayedExpansion
title Deploy Wit-T Blog

REM ---------------------------------------------------------------------------
REM  Deploy Wit-T Blog  ->  https://witt-blog.netlify.app
REM
REM  Publishes THIS folder to Netlify. It copies the site to a temporary
REM  staging folder first and deploys that, because `netlify deploy --dir`
REM  ignores .netlifyignore -- deploying the folder directly would publish
REM  .git, local config and draft files. Staging is what keeps them private.
REM
REM  To change what gets published, edit the EXCLUDE lines below.
REM ---------------------------------------------------------------------------

set "SITE_ID=566b44e8-c05a-4a67-8ed5-bdb2b528a535"
set "SITE_URL=https://witt-blog.netlify.app"

REM Pinned on purpose. An unpinned `npx netlify-cli` silently upgrades itself.
set "NETLIFY_CLI=netlify-cli@27.14.2"

set "SRC=%~dp0"
set "STAGE=%TEMP%\wittblog-deploy"

REM Folders never published
set "EXCLUDE_DIRS=.git .netlify .claude"
REM Files never published (drafts, repo metadata, this script)
set "EXCLUDE_FILES=.gitignore .gitattributes "index - Copy.html" *.bat"

echo.
echo  ================================================================
echo   Deploy Wit-T Blog
echo  ================================================================
echo   Source : %SRC%
echo   Target : %SITE_URL%
echo.

where npx >nul 2>&1
if errorlevel 1 (
  echo   ERROR: npx is not on PATH. Install Node.js, then re-run.
  echo.
  pause
  exit /b 1
)

if not exist "%SRC%index.html" (
  echo   ERROR: no index.html here. Run this from the blog folder.
  echo.
  pause
  exit /b 1
)

echo   Staging...
if exist "%STAGE%" rmdir /s /q "%STAGE%"
mkdir "%STAGE%" 2>nul

robocopy "%SRC%." "%STAGE%" /E /NFL /NDL /NJH /NJS /NP ^
  /XD %EXCLUDE_DIRS% /XF %EXCLUDE_FILES% >nul
if errorlevel 8 (
  echo   ERROR: staging failed ^(robocopy %%ERRORLEVEL%%^).
  echo.
  pause
  exit /b 1
)

REM --- prove the exclusions held before anything is published -----------------
set "LEAK=0"
for %%D in (%EXCLUDE_DIRS%) do if exist "%STAGE%\%%D" (
  echo   ABORT: %%D reached the staging folder.
  set "LEAK=1"
)
if exist "%STAGE%\index - Copy.html" (
  echo   ABORT: draft "index - Copy.html" reached the staging folder.
  set "LEAK=1"
)
if "!LEAK!"=="1" (
  echo.
  pause
  exit /b 1
)

set "COUNT=0"
for /r "%STAGE%" %%F in (*) do set /a COUNT+=1
echo   Staged !COUNT! files, dev folders and drafts excluded.

REM An argument skips the menu:  "Deploy Blog.bat" draft   /   "Deploy Blog.bat" prod
set "PICK="
if /i "%~1"=="draft" set "PICK=1"
if /i "%~1"=="prod"  set "PICK=2"

if not defined PICK (
  echo.
  echo  ----------------------------------------------------------------
  echo   [D]  Draft  - private preview URL, live site untouched
  echo   [P]  Publish - goes live at %SITE_URL%
  echo   [C]  Cancel
  echo  ----------------------------------------------------------------
  echo.
  choice /c DPC /n /m "  Choose (D/P/C): "
  set "PICK=!ERRORLEVEL!"
)
echo.

if "!PICK!"=="3" goto :cancelled
if "!PICK!"=="1" set "ARGS=" & set "WHAT=Draft"
if "!PICK!"=="2" set "ARGS=--prod" & set "WHAT=Production"

echo   %WHAT% deploy starting. First run may fetch the CLI; please wait.
echo.
REM Run from a scratch folder, NOT from %STAGE%. The CLI writes its resolved
REM config to .netlify\netlify.toml in the working directory; if that happens to
REM be the folder being uploaded, the file is published with the site (and it
REM embeds the absolute local publish path).
set "WORK=%TEMP%\wittblog-cli"
if exist "%WORK%" rmdir /s /q "%WORK%"
mkdir "%WORK%" 2>nul

pushd "%WORK%"
call npx --yes %NETLIFY_CLI% deploy %ARGS% --dir "%STAGE%" --site %SITE_ID% --message "Deploy Blog.bat (%WHAT%)"
set "RC=!ERRORLEVEL!"
popd

REM The upload folder must still hold exactly what was staged.
if exist "%STAGE%\.netlify" (
  echo   WARNING: the CLI still wrote .netlify into the upload folder.
)

echo.
if not "!RC!"=="0" (
  echo   DEPLOY FAILED ^(exit !RC!^). The live site was not changed.
  echo   If this mentions ERR_MODULE_NOT_FOUND, the npx cache is corrupt:
  echo     rename %%LOCALAPPDATA%%\npm-cache\_npx and run this again.
  echo.
  pause
  exit /b !RC!
)

if "!PICK!"=="2" (
  echo   Verifying...
  curl -s -o nul -w "   %SITE_URL%/ returned HTTP %%{http_code}%%" "%SITE_URL%/"
  echo.
)

echo.
echo   %WHAT% deploy complete.
echo.
echo   Reminder: this publishes files only. To save your changes to
echo   GitHub as well, run:  git add -A ^&^& git commit ^&^& git push
echo.
pause
exit /b 0

:cancelled
echo   Cancelled. Nothing was deployed.
echo.
pause
exit /b 0
