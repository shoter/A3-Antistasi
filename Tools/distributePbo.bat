:: quick system var help
:: ----------------------
:: shows variable: echo %FOOBAR%
:: >> TEMPORARY OPERATIONS
:: set variable: set FOOBAR=value
:: clean variable (before console exit): set FOOBAR=
:: >> PERMANENT OPERATIONS
:: set variable: setx FOOBAR value
:: permanently remove the variable from the user environment (which is the default place setx puts it): REG delete HKCU\Environment /F /V FOOBAR
:: if the variable is set in the system environment (e.g. if you originally set it with setx /M), as an administrator run: REG delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /F /V FOOBAR


@echo off
:: set local variable if you don't want to affect your env (to avoid commits, skip tree index of this file in git)
set SOURCE_DIR="d:\Users\rom\Documents\Arma 3 - Other Profiles\Czarny\mpmissions\AntistasiGithub\PreparedMissions"
set SOURCE_PBO=%SOURCE_DIR%\Antistasi-Altis-2-4.Altis
set SOURCE2_PBO=%SOURCE_DIR%\Antistasi-Virolahti-2-4.vt7
set DESTINATION_PBO="d:\Downloads\AntistasiAGN.Altis.pbo"
set DESTINATION2_PBO="d:\Downloads\AntistasiAGN.Virolahti.pbo"
set MISSION="d:\Downloads"

:: check if env variables exists
if "%SPBO%" NEQ "" set SOURCE_PBO=%SPBO%
if "%SPBO2%" NEQ "" set SOURCE2_PBO=%SPBO%
if "%DPBO%" NEQ "" set DESTINATION_PBO=%DPBO%
if "%DPBO%" NEQ "" set DESTINATION2_PBO=%DPBO%
if "%MCACHE%" NEQ "" set MISSION_CACHE=%MCACHE%
@echo on

cd /D "%~dp0"
pboManager\PBOConsole.exe -pack %SOURCE_PBO% %DESTINATION_PBO%
pboManager\PBOConsole.exe -pack %SOURCE2_PBO% %DESTINATION2_PBO%
echo F | xcopy %DESTINATION_PBO% %MISSION% /Y
echo F | xcopy %DESTINATION2_PBO% %MISSION% /Y

rmdir /S /Q %SOURCE_DIR%