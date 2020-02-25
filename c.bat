@ECHO OFF
CLS

IF [%1] == [] GOTO nofile
if not exist "%1" goto notfound

:compile
SET basename=%@NAME[%1]
SET outputFile=%basename%.exe
echo Removing compilation products...
DEL /e /t %outputFile% %basename%.obj

echo Compiling: %1
ml.exe %1
IF [%ERRORLEVEL%] == [0] GOTO run

echo Compilation error!
GOTO end

:run
for /f "tokens=1,* delims= " %%a in ("%*") do set ALL_BUT_FIRST=%%b
IF [%2] != [] (SET args= %ALL_BUT_FIRST%)
IF [%2] == [] (SET args=)

echo.
echo Compilation successful
echo Running: %outputFile%%args%
echo ======================= OUTPUT ==============================
%outputFile%%args%
GOTO end

:nofile
echo No file specified!
echo Usage: compile.bat filename.asm
GOTO end

:notfound
echo File [%1] not found!
GOTO end

:end