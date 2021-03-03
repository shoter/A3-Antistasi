#pathes
$sourceDir = "d:\!do przegrania\gry\Arma3\AntistasiGithub\PreparedMissions";
$pboDir = "d:\Downloads";
$missionsDir = "e:\gry\steam\steamapps\common\Arma 3\MPMissions";
$missions =  @('Antistasi-Altis-2-4.Altis','Antistasi-Virolahti-2-4.vt7','Antistasi-Livonia-2-4.Enoch');
$pboManager = "$PSScriptRoot\pboManager\PBOConsole.exe";

#creating pbo
ForEach ($mission in $missions) {
    $missionPbo = "AntistasiAGN." + $mission.split(".")[1] + ".pbo";
    &$pboManager '-pack' $sourceDir\$mission $pboDir\$missionPbo;
}

#copying and cleaning
Copy-Item -Path $pboDir\* -Include *.pbo -Destination $missionsDir -force;
Remove-Item $pboDir\* -Include *.pbo.bak;
Remove-Item $sourceDir\* -Recurse;