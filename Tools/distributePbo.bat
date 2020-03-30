set SOURCE_PBO="d:\Users\rom\Documents\Arma 3 - Other Profiles\Czarny\mpmissions\AntistasiGithub\PreparedMissions\Antistasi-Altis-2-2-1-AGN.Altis"
set DESTINATION_PBO="e:\gry\steam\steamapps\common\Arma 3 Server\mpmissions\AntistasiAGN.Altis.pbo"
set MISSION_CACHE="d:\Users\rom\AppData\Local\Arma 3\MPMissionsCache"
cd /D "%~dp0"
pboManager\PBOConsole.exe -pack %SOURCE_PBO% %DESTINATION_PBO%
xcopy %DESTINATION_PBO% %MISSION_CACHE% /Y
