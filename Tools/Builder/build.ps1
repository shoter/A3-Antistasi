<#
.SYNOPSIS
    Builds the Antistasi mod into a local mod folder for testing.

.DESCRIPTION
    Packs every folder under A3A\addons into a PBO with the bundled hemtt, copies mod.cpp, writes meta.cpp
    and the public key into <OutputPath>\<ModFolderName>.

    Settings are read from buildConfig.json next to this script. That file is git-ignored so every developer
    can point the build at their own Arma folder. Create it by copying buildConfig.template.json.

    Config keys:
        OutputPath     - folder that will contain the mod folder, e.g. "C:\\games\\A3\\Addons"
        ModFolderName  - name of the mod folder, default "@A3A"
        Sign           - true to create a temporary key and sign the PBOs (needs Arma 3 Tools' DSSignFile), default false
        KeyName        - key name used when Sign is true, default "a3a"

.PARAMETER ConfigPath
    Path to the JSON config. Defaults to buildConfig.json next to this script.

.PARAMETER ModFileName
    Which mod cpp to ship as mod.cpp (mod.cpp or mod_dev.cpp). Defaults to mod.cpp.

.EXAMPLE
    .\tools\Builder\build.ps1
    .\tools\Builder\build.ps1 -ModFileName mod_dev.cpp
#>
[CmdletBinding()]
param (
    [string]$ConfigPath = (Join-Path $PSScriptRoot "buildConfig.json"),
    [string]$ModFileName = "mod.cpp"
)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------- config
if (-not (Test-Path $ConfigPath)) {
    throw "Config file not found: $ConfigPath`nCopy buildConfig.template.json to buildConfig.json next to this script and set OutputPath."
}
$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

if ([string]::IsNullOrWhiteSpace($config.OutputPath)) { throw "OutputPath is not set in $ConfigPath" }
$outputPath    = $config.OutputPath
$modFolderName = if ($config.ModFolderName) { $config.ModFolderName } else { "@A3A" }
$sign          = [bool]$config.Sign
$keyName       = if ($config.KeyName) { $config.KeyName } else { "a3a" }

# ---------------------------------------------------------------- paths
$repoRoot   = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$sourceRoot = Join-Path $repoRoot "A3A"
$hemtt      = Join-Path $PSScriptRoot "hemtt.exe"
$signTools  = Join-Path $repoRoot "tools\DSSignFile"

if (-not (Test-Path $hemtt)) { throw "hemtt.exe not found in $PSScriptRoot" }
if (-not (Test-Path (Join-Path $sourceRoot $ModFileName))) { throw "$ModFileName not found in $sourceRoot" }

$modOut    = Join-Path $outputPath $modFolderName
$addonsOut = Join-Path $modOut "addons"
$keysOut   = Join-Path $modOut "Keys"

# ---------------------------------------------------------------- version
$version = ""
foreach ($line in (Get-Content (Join-Path $sourceRoot "addons\core\Includes\script_version.hpp"))) {
    if ($line -match "(?<= )([\w\d]*)(?![ \w\d])") { $version += $Matches[0] + "-" }
}
$version = $version.TrimEnd("-")

Write-Host "Antistasi $version"
Write-Host "Source : $sourceRoot"
Write-Host "Output : $modOut"

# ---------------------------------------------------------------- refuse to build while Arma has the PBOs open
$locked = Get-ChildItem $addonsOut -Filter "*.pbo" -ErrorAction SilentlyContinue | Where-Object {
    try { $s = [System.IO.File]::Open($_.FullName, 'Open', 'ReadWrite', 'None'); $s.Close(); $false } catch { $true }
}
if ($locked) {
    $arma = Get-Process -Name 'arma3server*', 'arma3*' -ErrorAction SilentlyContinue | ForEach-Object { "$($_.ProcessName) (PID $($_.Id))" }
    throw "PBOs in $addonsOut are in use ($($locked.Name -join ', ')). Stop Arma first: $($arma -join ', ')"
}

# ---------------------------------------------------------------- prepare output (only the generated parts are wiped)
New-Item -ItemType Directory -Force -Path $modOut | Out-Null
foreach ($dir in @($addonsOut, $keysOut)) {
    if (Test-Path $dir) { Remove-Item -Path $dir -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

# ---------------------------------------------------------------- pack addons
$modules = Get-ChildItem (Join-Path $sourceRoot "addons") -Directory
foreach ($module in $modules) {
    $pbo = Join-Path $addonsOut "$($module.Name).pbo"
    Write-Host "Building $($module.Name).pbo ..."
    & $hemtt armake pack --force $module.FullName $pbo
    if ($LASTEXITCODE -ne 0) { throw "hemtt failed while packing $($module.Name)" }
}

# ---------------------------------------------------------------- mod metadata
Copy-Item (Join-Path $sourceRoot $ModFileName) (Join-Path $modOut "mod.cpp") -Force
Set-Content -Path (Join-Path $modOut "meta.cpp") -Value "protocol = 1;`nname = `"$modFolderName`";"

# ---------------------------------------------------------------- keys / signing
if ($sign) {
    $createKey = Join-Path $signTools "DSCreateKey.exe"
    $signFile  = Join-Path $signTools "DSSignFile.exe"
    if (-not (Test-Path $createKey) -or -not (Test-Path $signFile)) { throw "Signing requested but DSCreateKey/DSSignFile not found in $signTools" }

    $keyWork = Join-Path ([System.IO.Path]::GetTempPath()) "a3a_build_key_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Force -Path $keyWork | Out-Null
    Push-Location $keyWork
    try {
        & $createKey $keyName
        if ($LASTEXITCODE -ne 0) { throw "DSCreateKey failed" }
        Copy-Item "$keyName.bikey" (Join-Path $keysOut "$keyName.bikey") -Force
        foreach ($pbo in Get-ChildItem $addonsOut -Filter "*.pbo") {
            Write-Host "Signing $($pbo.Name) ..."
            & $signFile "$keyWork\$keyName.biprivatekey" $pbo.FullName
            if ($LASTEXITCODE -ne 0) { throw "DSSignFile failed on $($pbo.Name)" }
        }
    } finally {
        Pop-Location
        Remove-Item $keyWork -Recurse -Force -ErrorAction SilentlyContinue
    }
} else {
    Copy-Item (Join-Path $sourceRoot "Keys\*.bikey") $keysOut -Force
}

Write-Host ""
Write-Host "Build complete: Antistasi $version -> $modOut ($(Get-Date))"
