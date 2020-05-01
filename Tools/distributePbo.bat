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
set SOURCE_PBO="d:\Users\rom\Documents\Arma 3 - Other Profiles\Czarny\mpmissions\AntistasiGithub\PreparedMissions\Antistasi-Altis-2-2-2-AGN.Altis"
set DESTINATION_PBO="e:\gry\steam\steamapps\common\Arma 3 Server\mpmissions\AntistasiAGN.Altis.pbo"
set MISSION_CACHE="d:\Users\rom\AppData\Local\Arma 3\MPMissionsCache"

:: check if env variables exists
if "%SPBO%" NEQ "" set SOURCE_PBO=%SPBO%
if "%DPBO%" NEQ "" set DESTINATION_PBO=%DPBO%
if "%MCACHE%" NEQ "" set MISSION_CACHE=%MCACHE%
@echo on

cd /D "%~dp0"
pboManager\PBOConsole.exe -pack %SOURCE_PBO% %DESTINATION_PBO%
xcopy %DESTINATION_PBO% %MISSION_CACHE% /Y
