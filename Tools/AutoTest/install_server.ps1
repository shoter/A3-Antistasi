<#
.SYNOPSIS
    Installs or updates the Arma 3 dedicated server used by launch_tests.ps1, with SteamCMD.

.DESCRIPTION
    Paths come from autotest.settings.ps1 and the git-ignored autotest.settings.local.ps1 next to this script,
    so an existing install (e.g. C:\games\A3\Arma3\A3Master) is updated in place instead of downloading a second copy.

    Steam refuses anonymous downloads of app 233780 ('No subscription'), so SteamCMD logs in with an account
    that owns Arma 3:
      - STEAM_USERNAME from the environment, else SteamUser from the settings.
      - STEAM_CONFIG_VDF from the environment (CI): a cached SteamCMD session (config\config.vdf, raw or base64),
        so no password and no Steam Guard code are needed. Locally SteamCMD uses its own cached login, or asks.

    A server installed from a beta branch (e.g. creatordlc) stays on that branch.

.EXAMPLE
    .\Tools\AutoTest\install_server.ps1
    .\Tools\AutoTest\install_server.ps1 -Validate
#>
[CmdletBinding()]
param(
    [string]$ServerDir,
    [string]$SteamCmdDir,
    [string]$SteamUser,
    [switch]$Validate                    # check every file, slower
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

# ---------------------------------------------------------------- settings (command line > local file > defaults)
$Settings = @{}
. (Join-Path $PSScriptRoot 'autotest.settings.ps1')
$localSettings = Join-Path $PSScriptRoot 'autotest.settings.local.ps1'
if (Test-Path $localSettings) { . $localSettings }
foreach ($name in 'ServerDir', 'SteamCmdDir', 'SteamUser') {
    if (-not $PSBoundParameters.ContainsKey($name)) { Set-Variable -Name $name -Value $Settings[$name] }
}
if ($env:STEAM_USERNAME) { $SteamUser = $env:STEAM_USERNAME }
if (-not $SteamUser) {
    throw ("Steam refuses anonymous downloads of the Arma 3 server (app 233780). Set SteamUser in " +
           "$localSettings or the STEAM_USERNAME environment variable to an account that owns Arma 3.")
}

$AppId = 233780
$steamcmd = Join-Path $SteamCmdDir 'steamcmd.exe'
New-Item -ItemType Directory -Force -Path $SteamCmdDir, $ServerDir | Out-Null

# ---------------------------------------------------------------- SteamCMD
if (-not (Test-Path $steamcmd)) {
    Write-Host "Downloading SteamCMD to $SteamCmdDir"
    $zip = Join-Path $SteamCmdDir 'steamcmd.zip'
    Invoke-WebRequest 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip' -OutFile $zip
    Expand-Archive $zip -DestinationPath $SteamCmdDir -Force
    Remove-Item $zip -Force
    # First start only updates SteamCMD itself and exits with a non-zero code
    & $steamcmd +quit | Out-Null
}

if ($env:STEAM_CONFIG_VDF) {
    $vdf = $env:STEAM_CONFIG_VDF.Trim()
    if ($vdf -notmatch '^\s*"') { $vdf = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($vdf)) }
    $configDir = Join-Path $SteamCmdDir 'config'
    New-Item -ItemType Directory -Force -Path $configDir | Out-Null
    Set-Content -Path (Join-Path $configDir 'config.vdf') -Value $vdf -Encoding UTF8 -NoNewline
    Write-Host 'Using the cached Steam session from STEAM_CONFIG_VDF'
}

# ---------------------------------------------------------------- server
# Keep the installed branch: app_update without -beta would switch a creatordlc install back to public
$branchArgs = @()
$manifest = Join-Path $ServerDir 'steamapps\appmanifest_233780.acf'
if (Test-Path $manifest) {
    $m = Select-String -Path $manifest -Pattern '"BetaKey"\s+"([^"]+)"' | Select-Object -First 1
    if ($m) { $branchArgs = @('-beta', $m.Matches[0].Groups[1].Value); Write-Host "Installed branch: $($branchArgs[1])" }
}

$updateArgs = @('+force_install_dir', $ServerDir, '+login', $SteamUser, '+app_update', $AppId) + $branchArgs
if ($Validate) { $updateArgs += 'validate' }
$updateArgs += '+quit'

Write-Host "Installing or updating the Arma 3 server in $ServerDir as $SteamUser"
$ok = $false
for ($i = 1; $i -le 3 -and -not $ok; $i++) {
    & $steamcmd @updateArgs
    $code = $LASTEXITCODE
    Write-Host "steamcmd attempt $i exit code $code"
    $ok = $code -eq 0 -and (Test-Path (Join-Path $ServerDir 'arma3server_x64.exe'))
}
if (-not $ok) { throw "SteamCMD could not install or update the Arma 3 server in $ServerDir (see the SteamCMD output above)" }

$size = (Get-ChildItem $ServerDir -Recurse -File | Measure-Object Length -Sum).Sum / 1GB
Write-Host ('Arma 3 server ready: {0} ({1:N1} GB)' -f $ServerDir, $size)
