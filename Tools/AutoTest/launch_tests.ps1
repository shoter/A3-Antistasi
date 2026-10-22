<#
.SYNOPSIS
    Runs the Antistasi automated tests on a local dedicated server and prints a summary.

.DESCRIPTION
    1. Builds the mod with Tools\Builder\build.ps1 (skip with -NoBuild).
    2. Groups the selected tests by how they need the campaign started (map, new game or save, factions, params).
    3. For each group: packs the test addon (Tools\AutoTest\addon + the group's tests) into a server-only mod,
       starts arma3server_x64.exe with its own profile under Tools\AutoTest\work\server, no players needed,
       follows the RPT live, and stops the server when the tests are done.
    4. Prints a summary with every failed test and the script errors attributed to it.
       Results, the RPT and the error list are kept in Tools\AutoTest\work\results\<run id>.

    Test files live in Tools\AutoTest\tests\*.sqf (files starting with _ are skipped). Header lines:
        // @description: what the test checks
        // @timeout: 120                 seconds, default 120
        // @start: new                   or: load <gameID>   (save taken from -SaveProfile)
        // @world: Altis                 map, default Altis
        // @factions: occ,inv,reb,civ    template names, empty entries = setup dialog defaults
        // @param: name=value            mission param override, repeatable

    Everything under Tools\AutoTest\work is git-ignored: the copied server profile and saves, RPTs, packed PBOs.

.EXAMPLE
    .\Tools\AutoTest\launch_tests.ps1
    .\Tools\AutoTest\launch_tests.ps1 -Test smoke_* -NoBuild
    .\Tools\AutoTest\launch_tests.ps1 -List
    .\Tools\AutoTest\launch_tests.ps1 -Vanilla -KeepServer
#>
[CmdletBinding()]
param(
    [string[]]$Test = @('*'),                       # test name patterns (wildcards)
    [switch]$List,                                  # list the tests and exit
    [switch]$NoBuild,                               # do not rebuild @A3A first
    [switch]$Vanilla,                               # only @A3A, ignore the mods file
    [switch]$KeepServer,                            # leave the last server running after the tests
    [switch]$ShowInfo,                              # print INFO lines from tests while running
    [switch]$StrictLog,                             # also fail on Antistasi 'Error' log lines, not only script errors
    [string]$ServerDir   = 'C:\games\A3\Arma3\A3Master',
    [string]$ModsFile    = 'C:\games\A3\configs\Antistasi Debug\mods.txt',
    [string]$WorkshopDir = 'C:\games\A3\Steam\steamapps\workshop\content\107410',
    [string]$SaveProfile = 'C:\games\A3\configs\Antistasi Debug\Users\AntistasiServer',  # copied, never written
    [int]$Port = 2402,
    [int]$StartupTimeoutMinutes = 30,               # server launch until the first test starts
    [int]$SettleSeconds = 15                        # wait after server init before the first test
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

# ---------------------------------------------------------------- paths
$Root      = $PSScriptRoot
$RepoRoot  = (Resolve-Path (Join-Path $Root '..\..')).Path
$TestsDir  = Join-Path $Root 'tests'
$AddonDir  = Join-Path $Root 'addon'
$WorkDir   = Join-Path $Root 'work'
$StageDir  = Join-Path $WorkDir 'stage'
$TestMod   = Join-Path $WorkDir 'mod\@A3A_AutoTest'
$ServerWork = Join-Path $WorkDir 'server'
$Hemtt     = Join-Path $RepoRoot 'Tools\Builder\hemtt.exe'
$BuildPs1  = Join-Path $RepoRoot 'Tools\Builder\build.ps1'
$ServerExe = Join-Path $ServerDir 'arma3server_x64.exe'
$ProfileName = 'A3ATest'
$PidFile   = Join-Path $WorkDir 'server.pid'

$RunId     = Get-Date -Format 'yyyyMMdd-HHmmss'
$ResultDir = Join-Path $WorkDir "results\$RunId"
$RunStart  = Get-Date

# ---------------------------------------------------------------- output helpers
function Format-Elapsed([TimeSpan]$t) {
    if ($t.TotalHours -ge 1) { return '{0}h{1:00}m' -f [int][math]::Floor($t.TotalHours), $t.Minutes }
    return '{0:00}:{1:00}' -f [int][math]::Floor($t.TotalMinutes), $t.Seconds
}
function Write-Step([string]$Text, [string]$Color = 'Gray') {
    Write-Host ('  [{0}] {1}' -f (Format-Elapsed ((Get-Date) - $RunStart)), $Text) -ForegroundColor $Color
}
function Write-Rule([string]$Text) {
    Write-Host ''
    Write-Host ('-- ' + $Text + ' ' + ('-' * [math]::Max(0, 70 - $Text.Length))) -ForegroundColor Cyan
}
$StatusColor = @{ PASS = 'Green'; FAIL = 'Red'; ERROR = 'Red'; TIMEOUT = 'Yellow'; 'NOT RUN' = 'DarkYellow' }

# ---------------------------------------------------------------- test discovery
function Get-TestDefinitions {
    $files = Get-ChildItem $TestsDir -Filter '*.sqf' | Sort-Object Name
    foreach ($f in $files) {
        $t = [ordered]@{
            Name = $f.BaseName; Description = ''; Timeout = 120; Start = 'new'; GameID = ''
            World = 'Altis'; Factions = @('', '', '', ''); Params = [ordered]@{}; File = $f.FullName
        }
        foreach ($line in Get-Content $f.FullName) {
            if ($line -notmatch '^\s*//') { break }
            if ($line -notmatch '^\s*//\s*@(\w+)\s*:\s*(.*?)\s*$') { continue }
            $key = $Matches[1].ToLower(); $val = $Matches[2]
            switch ($key) {
                'description' { $t.Description = $val }
                'timeout'     { $t.Timeout = [int]$val }
                'world'       { $t.World = $val }
                'start' {
                    $parts = $val -split '\s+', 2
                    $t.Start = $parts[0].ToLower()
                    if ($t.Start -eq 'load') {
                        if ($parts.Count -lt 2) { throw "$($f.Name): '@start: load' needs a game ID" }
                        $t.GameID = $parts[1]
                    } elseif ($t.Start -ne 'new') { throw "$($f.Name): @start must be 'new' or 'load <gameID>'" }
                }
                'factions' {
                    $fac = @($val -split ',' | ForEach-Object { $_.Trim() })
                    while ($fac.Count -lt 4) { $fac += '' }
                    $t.Factions = $fac[0..3]
                }
                'param' {
                    if ($val -notmatch '^(\w+)\s*=\s*(.+)$') { throw "$($f.Name): bad @param '$val', expected name=value" }
                    $t.Params[$Matches[1]] = $Matches[2].Trim()
                }
                default { Write-Warning "$($f.Name): unknown header @$key" }
            }
        }
        [pscustomobject]$t
    }
}

function Get-GroupKey($t) {
    $p = ($t.Params.Keys | Sort-Object | ForEach-Object { "$_=$($t.Params[$_])" }) -join ';'
    "$($t.World)|$($t.Start)|$($t.GameID)|$($t.Factions -join ',')|$p"
}

function Get-GroupLabel($t) {
    $label = if ($t.Start -eq 'load') { "$($t.World), save $($t.GameID)" } else { "$($t.World), new game" }
    if (($t.Factions -join '') -ne '') { $label += ", factions $($t.Factions -join '/')" }
    if ($t.Params.Count) { $label += ", params " + (($t.Params.Keys | ForEach-Object { "$_=$($t.Params[$_])" }) -join ' ') }
    $label
}

# ---------------------------------------------------------------- SQF literal helpers
function ConvertTo-SqfString([string]$s) { '"' + $s.Replace('"', '""') + '"' }
function ConvertTo-SqfValue([string]$s) {
    $n = 0.0
    if ([double]::TryParse($s, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$n)) { return $s }
    if ($s -in @('true', 'false')) { return $s }
    ConvertTo-SqfString $s
}

function New-RunConfig($group) {
    $t0 = $group[0]
    $tests = ($group | ForEach-Object { '[' + (ConvertTo-SqfString $_.Name) + ', ' + $_.Timeout + ']' }) -join ', '
    $factions = ($t0.Factions | ForEach-Object { ConvertTo-SqfString $_ }) -join ', '
    $params = ($t0.Params.Keys | ForEach-Object { '[' + (ConvertTo-SqfString $_) + ', ' + (ConvertTo-SqfValue $t0.Params[$_]) + ']' }) -join ', '
    @"
// Generated by launch_tests.ps1 for run $RunId
createHashMapFromArray [
    ["runId", $(ConvertTo-SqfString $RunId)],
    ["start", $(ConvertTo-SqfString $t0.Start)],
    ["gameID", $(ConvertTo-SqfString $t0.GameID)],
    ["factions", [$factions]],
    ["params", [$params]],
    ["initTimeout", $($StartupTimeoutMinutes * 60)],
    ["settleSeconds", $SettleSeconds],
    ["tests", [$tests]]
]
"@
}

# ---------------------------------------------------------------- mods
function Get-ModPaths {
    $a3a = 'C:\games\A3\Addons\@A3A'
    $buildCfg = Join-Path $RepoRoot 'Tools\Builder\buildConfig.json'
    if (Test-Path $buildCfg) {
        $c = Get-Content $buildCfg -Raw | ConvertFrom-Json
        $folder = if ($c.ModFolderName) { $c.ModFolderName } else { '@A3A' }
        if ($c.OutputPath) { $a3a = Join-Path $c.OutputPath $folder }
    }
    if ($Vanilla) { return @($a3a) }

    if (-not (Test-Path $ModsFile)) { throw "Mods file not found: $ModsFile (use -ModsFile or -Vanilla)" }
    $paths = @(); $missing = @()
    foreach ($line in Get-Content $ModsFile) {
        $line = $line.Trim()
        if ($line -eq '' -or $line.StartsWith('#')) { continue }
        $id = ($line -split '\s+', 2)[0]
        $dir = if ($id -match '^[A-Za-z]:\\') { $id } elseif ($id -match '^\d+$') { Join-Path $WorkshopDir $id } else { continue }
        if (Test-Path $dir) { $paths += $dir } else { $missing += $line }
    }
    if ($missing) { throw "Mods from $ModsFile are missing:`n  $($missing -join "`n  ")" }
    if (-not ($paths | Where-Object { $_ -ieq $a3a })) { $paths += $a3a }
    return $paths
}

# ---------------------------------------------------------------- server profile and config
function Initialize-ServerProfile {
    $users = Join-Path $ServerWork "Users\$ProfileName"
    if (Test-Path $users) { Remove-Item $users -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $users | Out-Null
    if (-not (Test-Path $SaveProfile)) { return $false }

    # Fresh copy every run: tests may save, the source profile is never touched
    $srcName = Split-Path $SaveProfile -Leaf
    Get-ChildItem $SaveProfile -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($SaveProfile.Length).TrimStart('\')
        $leaf = Split-Path $rel -Leaf
        $parent = Split-Path $rel -Parent
        if ($leaf.StartsWith("$srcName.")) { $leaf = $ProfileName + $leaf.Substring($srcName.Length) }
        $dest = if ($parent) { Join-Path (Join-Path $users $parent) $leaf } else { Join-Path $users $leaf }
        New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
        Copy-Item $_.FullName $dest -Force
    }
    return (Test-Path (Join-Path $users "$ProfileName.Arma3Profile"))
}

function Write-ServerConfig([string]$World, [bool]$CustomDifficulty) {
    $difficulty = if ($CustomDifficulty) { 'Custom' } else { 'Regular' }
    $pw = -join ((1..16) | ForEach-Object { [char](Get-Random -Minimum 97 -Maximum 123) })
    $cfg = @"
// Generated by launch_tests.ps1, run $RunId. Local test server: loopback only, starts without players.
hostname = "A3A AutoTest $RunId";
password = "$pw";
passwordAdmin = "$pw";
serverCommandPassword = "$pw";
loopback = true;
upnp = false;
persistent = 1;
autoSelectMission = true;
BattlEye = 0;
verifySignatures = 0;
kickDuplicate = 1;
maxPlayers = 4;
disableVoN = 1;
statisticsEnabled = 0;
timeStampFormat = "short";
logFile = "server_console.log";
forcedDifficulty = "$difficulty";
allowedLoadFileExtensions[] = {"hpp","sqf","sqm","txt","inc","ext","json"};
allowedPreprocessFileExtensions[] = {"hpp","sqf","sqm","txt","inc","ext"};
class Missions {
    class A3A_AutoTest {
        template = "Antistasi_$World.$World";
        difficulty = "$difficulty";
        class Params { autoLoadLastGame = -1; };
    };
};
"@
    $path = Join-Path $ServerWork 'server.cfg'
    Set-Content -Path $path -Value $cfg -Encoding ASCII
    $path
}

function Stop-TestServer([int]$ProcessId) {
    $p = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if ($p -and $p.ProcessName -like 'arma3server*') {
        Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
        $p.WaitForExit(30000) | Out-Null
    }
    if (Test-Path $PidFile) { Remove-Item $PidFile -Force -ErrorAction SilentlyContinue }
}

# ---------------------------------------------------------------- RPT parsing
$script:ErrorMarker = 'x\\a3a|a3a_autotest|antistasi'

function New-RunState($group) {
    $results = [ordered]@{}
    foreach ($t in $group) {
        $results[$t.Name] = [pscustomobject]@{
            Name = $t.Name; Group = (Get-GroupLabel $t); Status = 'NOT RUN'; Seconds = 0; Message = ''
            Asserts = New-Object System.Collections.ArrayList; Info = New-Object System.Collections.ArrayList
            ScriptErrors = New-Object System.Collections.ArrayList
        }
    }
    [pscustomobject]@{
        Results = $results; CurrentTest = $null; Done = $false; Fatal = $null; Phase = 'starting server'
        StartupErrors = New-Object System.Collections.ArrayList   # script errors outside tests
        LogErrors = New-Object System.Collections.ArrayList       # '| Antistasi | Error |' lines
        ErrBlock = $null; Completed = 0; Total = $group.Count; Tail = New-Object System.Collections.Queue
    }
}

function Complete-ErrorBlock($state) {
    $b = $state.ErrBlock
    if (-not $b) { return }
    $state.ErrBlock = $null
    $reason = @($b.Lines | Where-Object { $_ -notmatch '^Error (in expression|position)' })
    if (-not $reason) { $reason = @($b.Lines | Select-Object -First 1) }
    $text = ($reason -join ' | ')
    if ($b.File) { $text += " @ $($b.File)" }
    $err = [pscustomobject]@{ Text = $text; File = $b.File; Test = $state.CurrentTest; Relevant = (($b.File + ' ' + $b.Code) -match $script:ErrorMarker) }
    if ($state.CurrentTest) { [void]$state.Results[$state.CurrentTest].ScriptErrors.Add($err) }
    else { [void]$state.StartupErrors.Add($err) }
}

function Read-RptLine($state, [string]$raw) {
    $line = $raw -replace '^\s*\d{1,2}:\d{2}:\d{2}\s', ''
    $state.Tail.Enqueue($line); if ($state.Tail.Count -gt 25) { [void]$state.Tail.Dequeue() }

    # Script error blocks: "Error in expression <code...>" (the code may span raw lines), "Error position: <...>",
    # "Error <reason>", then "File <path>..., line N" closes the block
    $isOwnLine = $line.Contains('A3A_TEST|') -or $line -match '\|\s*Antistasi\s*\|' -or $line -match '^\s*Error in expression'
    if ($state.ErrBlock -and -not $isOwnLine) {
        $b = $state.ErrBlock
        $b.Count++
        if ($line -match '^\s*File\s+(.+)$') { $b.File = $Matches[1].Trim(); Complete-ErrorBlock $state; return }
        if ($line -match '^\s*Error\s') { [void]$b.Lines.Add($line.Trim()) }
        elseif ($b.Count -le 6) { $b.Code += ' ' + $line.Trim() }
        if ($b.Count -gt 30) { Complete-ErrorBlock $state }
        return
    }
    if ($state.ErrBlock) { Complete-ErrorBlock $state }
    if ($line -match '^\s*Error in expression') {
        $state.ErrBlock = [pscustomobject]@{ Lines = (New-Object System.Collections.ArrayList); File = ''; Code = $line.Trim(); Count = 0 }
        [void]$state.ErrBlock.Lines.Add($line.Trim())
        return
    }
    if ($line -match '\|\s*Antistasi\s*\|\s*Error\s*\|') {
        [void]$state.LogErrors.Add([pscustomobject]@{ Text = $line.Trim(); Test = $state.CurrentTest })
        return
    }

    $i = $line.IndexOf('A3A_TEST|')
    if ($i -lt 0) { return }
    $f = $line.Substring($i).TrimEnd('"').Split('|')
    switch ($f[1]) {
        'PHASE' {
            switch ($f[2]) {
                'postInit'       { $state.Phase = 'mission loaded'; Write-Step "Mission loaded: $($f[4]) on $($f[3])" }
                'setupMonitor'   { $state.Phase = 'starting campaign'; Write-Step 'Antistasi setup monitor is waiting, starting the campaign' }
                'campaignStart'  { $state.Phase = 'server init'; Write-Step ("Campaign start: {0} {1} factions {2}" -f $f[3], $f[4], $f[5]) }
                'startupState'   { $state.Phase = "server init ($($f[3]))"; Write-Step "  startup state: $($f[3])" 'DarkGray' }
                'serverInitDone' { $state.Phase = 'settling'; Write-Step "Server init done in $($f[3]) s" 'Green' }
                'settling'       { Write-Step "Letting the server settle for $($f[3]) s" 'DarkGray' }
            }
        }
        'PLAN'  { $state.Phase = 'running tests' }
        'BEGIN' {
            $state.CurrentTest = $f[4]
            $state.Phase = "running $($f[4])"
            $script:CurrentBegin = Get-Date
        }
        'ASSERT' { if ($state.Results.Contains($f[2])) { [void]$state.Results[$f[2]].Asserts.Add($f[3]) } }
        'INFO' {
            if ($state.Results.Contains($f[2])) { [void]$state.Results[$f[2]].Info.Add($f[3]) }
            if ($ShowInfo) { Write-Step "    info: $($f[3])" 'DarkGray' }
        }
        'RESULT' {
            Complete-ErrorBlock $state
            $r = $state.Results[$f[3]]
            $r.Status = $f[4]; $r.Seconds = [double]::Parse($f[5], [Globalization.CultureInfo]::InvariantCulture); $r.Message = $f[6]
            # An error in the test file itself is the most useful one to show, helpers report theirs first
            $relevant = @($r.ScriptErrors | Where-Object { $_.Relevant } | Sort-Object { if ($_.File -like '*\tests\*') { 0 } else { 1 } })
            if ($r.Status -eq 'PASS' -and $relevant.Count) { $r.Status = 'FAIL'; $r.Message = "script error during the test: $($relevant[0].Text)" }
            if ($StrictLog -and $r.Status -eq 'PASS') {
                $logErr = @($state.LogErrors | Where-Object { $_.Test -eq $r.Name })
                if ($logErr.Count) { $r.Status = 'FAIL'; $r.Message = "Antistasi error logged: $($logErr[0].Text)" }
            }
            $state.CurrentTest = $null
            $state.Completed++
            $script:TestsDone++
            Write-TestResult $r $f[2] $f[3]
        }
        'DONE'  { $state.Done = $true }
        'FATAL' { $state.Fatal = $f[2]; Write-Step "FATAL: $($f[2])" 'Red' }
    }
}

function Write-TestResult($r, $index, $count) {
    $label = '{0,3}/{1,-3} {2} ' -f $script:TestsDone, $script:TestsTotal, $r.Name
    $dots = '.' * [math]::Max(2, 52 - $label.Length)
    $line = '  {0}{1} {2,-7} {3,6:0.0}s' -f $label, $dots, $r.Status, $r.Seconds
    if ($r.Status -ne 'PASS' -and $r.Message) { $line += "  $($r.Message)" }
    Write-Host $line -ForegroundColor $StatusColor[$r.Status]
}

function Update-Progress($state, [string]$GroupText) {
    $pct = if ($script:TestsTotal) { [int](100 * $script:TestsDone / $script:TestsTotal) } else { 0 }
    Write-Progress -Id 1 -Activity "Antistasi tests: $($script:TestsDone)/$($script:TestsTotal) done" `
        -Status "$GroupText - $($state.Phase)" -PercentComplete $pct `
        -CurrentOperation ('elapsed ' + (Format-Elapsed ((Get-Date) - $RunStart)))
}

# ---------------------------------------------------------------- one server run
function Invoke-TestGroup($group, [int]$GroupIndex, [int]$GroupCount, [string[]]$ModPaths, [bool]$CustomDifficulty) {
    $t0 = $group[0]
    $groupText = "run $GroupIndex/$GroupCount ($(Get-GroupLabel $t0))"
    Write-Rule "Server $groupText, $($group.Count) test(s)"
    $state = New-RunState $group

    # Pack the test addon with this group's tests and run config
    if (Test-Path $StageDir) { Remove-Item $StageDir -Recurse -Force }
    Copy-Item $AddonDir $StageDir -Recurse
    New-Item -ItemType Directory -Force -Path (Join-Path $StageDir 'tests') | Out-Null
    foreach ($t in $group) { Copy-Item $t.File (Join-Path $StageDir "tests\$($t.Name).sqf") }
    Set-Content -Path (Join-Path $StageDir 'run_config.sqf') -Value (New-RunConfig $group) -Encoding ASCII
    $pbo = Join-Path $TestMod 'addons\a3a_autotest.pbo'
    New-Item -ItemType Directory -Force -Path (Split-Path $pbo -Parent) | Out-Null
    $packOut = & $Hemtt armake pack --force $StageDir $pbo 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Packing the test addon failed:`n$packOut" }

    $cfgPath = Write-ServerConfig -World $t0.World -CustomDifficulty $CustomDifficulty
    $serverArgs = @(
        "-port=$Port", "-config=$cfgPath", "-profiles=$ServerWork", "-name=$ProfileName",
        '-world=empty', '-autoInit', '-loadMissionToMemory', '-noSound',
        "-mod=$($ModPaths -join ';')", "-serverMod=$TestMod"
    )
    $quoted = $serverArgs | ForEach-Object { if ($_ -match '\s') { "`"$_`"" } else { $_ } }

    $oldRpts = @(Get-ChildItem $ServerWork -Filter 'arma3server_x64_*.rpt' -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    $launchTime = Get-Date
    $proc = Start-Process -FilePath $ServerExe -ArgumentList $quoted -WorkingDirectory $ServerDir -WindowStyle Minimized -PassThru
    Set-Content -Path $PidFile -Value $proc.Id
    Write-Step "Server started (PID $($proc.Id), port $Port)"

    $testBudget = ($group | Measure-Object -Property Timeout -Sum).Sum + 30 * $group.Count
    $startupDeadline = $launchTime.AddMinutes($StartupTimeoutMinutes)
    $rpt = $null; $reader = $null; $pending = ''
    $outcome = $null
    try {
        while ($true) {
            Update-Progress $state $groupText

            if (-not $rpt) {
                $rpt = Get-ChildItem $ServerWork -Filter 'arma3server_x64_*.rpt' -ErrorAction SilentlyContinue |
                    Where-Object { $oldRpts -notcontains $_.Name } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if ($rpt) {
                    Write-Step "RPT: $($rpt.FullName)" 'DarkGray'
                    $fs = [IO.File]::Open($rpt.FullName, 'Open', 'Read', 'ReadWrite, Delete')
                    $reader = New-Object IO.StreamReader($fs)
                }
            }
            if ($reader) {
                $chunk = $reader.ReadToEnd()
                if ($chunk) {
                    $text = $pending + $chunk
                    $lines = $text -split "`r?`n"
                    $pending = $lines[-1]
                    for ($i = 0; $i -lt $lines.Count - 1; $i++) { Read-RptLine $state $lines[$i] }
                }
            }

            if ($state.Done) { $outcome = 'done'; break }
            if ($state.Fatal) { $outcome = 'fatal'; break }
            if ($proc.HasExited) { $outcome = "server exited (code $($proc.ExitCode))"; break }
            $now = Get-Date
            if ($state.Completed -eq 0 -and -not $state.CurrentTest -and $now -gt $startupDeadline) {
                $outcome = "startup timeout: no test started within $StartupTimeoutMinutes min (last phase: $($state.Phase))"; break
            }
            if (($state.Completed -gt 0 -or $state.CurrentTest) -and $now -gt $startupDeadline.AddSeconds($testBudget)) {
                $outcome = "test timeout: tests did not finish within $testBudget s"; break
            }
            Start-Sleep -Milliseconds 500
        }
        if ($reader) {
            Start-Sleep -Milliseconds 500
            foreach ($l in (($pending + $reader.ReadToEnd()) -split "`r?`n")) { if ($l) { Read-RptLine $state $l } }
            Complete-ErrorBlock $state
        }
    } finally {
        if ($reader) { $reader.Dispose() }
        $keep = $KeepServer -and $GroupIndex -eq $GroupCount
        if ($keep) { Write-Step "Server kept running (PID $($proc.Id)); stop it with: Stop-Process -Id $($proc.Id)" 'Yellow' }
        else { Stop-TestServer $proc.Id }
    }

    if ($outcome -ne 'done') {
        $reason = if ($state.Fatal) { "FATAL: $($state.Fatal)" } else { $outcome }
        Write-Step "Run aborted: $reason" 'Red'
        Write-Host '    Last RPT lines:' -ForegroundColor DarkGray
        foreach ($l in $state.Tail) { Write-Host "      $l" -ForegroundColor DarkGray }
        foreach ($r in $state.Results.Values) {
            if ($r.Status -eq 'NOT RUN') { $r.Message = $reason; $script:TestsDone++ }
        }
    }

    # Startup script errors become a synthetic check of this run
    $startupRelevant = @($state.StartupErrors | Where-Object { $_.Relevant })
    $startupCheck = [pscustomobject]@{
        Name = '[rpt] no Antistasi script errors during startup'; Group = (Get-GroupLabel $t0)
        Status = if ($startupRelevant.Count) { 'FAIL' } else { 'PASS' }; Seconds = 0
        Message = if ($startupRelevant.Count) { "$($startupRelevant.Count) error(s), first: $($startupRelevant[0].Text)" } else { '' }
        Asserts = @(); Info = @(); ScriptErrors = $startupRelevant
    }
    $countStartupCheck = $outcome -eq 'done' -or $startupRelevant.Count
    if ($countStartupCheck) {
        Write-Host ("  {0} {1}  ({2} script error(s) outside tests, {3} from Antistasi/test files)" -f $startupCheck.Name, $startupCheck.Status, $state.StartupErrors.Count, $startupRelevant.Count) -ForegroundColor $StatusColor[$startupCheck.Status]
    }

    # Keep the evidence
    if ($rpt) { Copy-Item $rpt.FullName (Join-Path $ResultDir ("run{0}_{1}" -f $GroupIndex, $rpt.Name)) -ErrorAction SilentlyContinue }
    [pscustomobject]@{
        Label = Get-GroupLabel $t0; Outcome = $outcome; Rpt = $(if ($rpt) { $rpt.FullName } else { '' })
        Results = @($state.Results.Values) + @($startupCheck | Where-Object { $countStartupCheck })
        StartupErrors = @($state.StartupErrors); LogErrors = @($state.LogErrors)
    }
}

# ================================================================ main
# Tests starting with _ (harness self-tests, drafts) run only when a pattern starting with _ asks for them
$all = @(Get-TestDefinitions)
$selected = @($all | Where-Object {
    $n = $_.Name
    @($Test | Where-Object { $n -like $_ -and (-not $n.StartsWith('_') -or $_.StartsWith('_')) }).Count -gt 0
})

if ($List) {
    Write-Host "Tests in $TestsDir" -ForegroundColor Cyan
    foreach ($t in $all) {
        Write-Host ('  {0,-34} {1,5}s  {2,-24} {3}' -f $t.Name, $t.Timeout, (Get-GroupLabel $t), $t.Description)
    }
    return
}
if (-not $selected) { throw "No tests match: $($Test -join ', ')" }
if (-not (Test-Path $ServerExe)) { throw "Server executable not found: $ServerExe" }
if (-not (Test-Path $Hemtt)) { throw "hemtt.exe not found: $Hemtt" }

# Stop a test server left behind by an aborted run
if (Test-Path $PidFile) { Stop-TestServer ([int](Get-Content $PidFile -Raw)) }

New-Item -ItemType Directory -Force -Path $ResultDir, $ServerWork | Out-Null
$groups = @($selected | Group-Object { Get-GroupKey $_ } | ForEach-Object { , @($_.Group) })
$modPaths = @(Get-ModPaths)
$script:TestsTotal = $selected.Count
$script:TestsDone = 0

Write-Host ''
Write-Host 'Antistasi automated tests' -ForegroundColor Cyan
Write-Host ("  Run id    $RunId")
Write-Host ("  Tests     {0} selected of {1}, in {2} server run(s)" -f $selected.Count, $all.Count, $groups.Count)
Write-Host ("  Modset    {0} ({1} mod folder(s))" -f $(if ($Vanilla) { 'vanilla + Antistasi' } else { "from $ModsFile" }), $modPaths.Count)
Write-Host ("  Server    $ServerExe, port $Port, loopback only")
Write-Host ("  Results   $ResultDir")

$customDifficulty = Initialize-ServerProfile
if (-not $customDifficulty) { Write-Host "  Note      no server profile at $SaveProfile, using Regular difficulty and no saves" -ForegroundColor Yellow }

$runs = @()
try {
    if (-not $NoBuild) {
        Write-Rule 'Build'
        Write-Step 'Building @A3A with Tools\Builder\build.ps1'
        $buildLog = Join-Path $ResultDir 'build.log'
        try { & $BuildPs1 *> $buildLog }
        catch { Write-Step "Build failed: $($_.Exception.Message) (log: $buildLog)" 'Red'; exit 2 }
        Write-Step 'Build done' 'Green'
    }

    for ($g = 0; $g -lt $groups.Count; $g++) {
        if ($g -gt 0) { [void](Initialize-ServerProfile) }        # every run starts from the same saves
        $runs += Invoke-TestGroup $groups[$g] ($g + 1) $groups.Count $modPaths $customDifficulty
    }
} finally {
    Write-Progress -Id 1 -Activity 'Antistasi tests' -Completed
}

# ---------------------------------------------------------------- summary
$results = @($runs | ForEach-Object { $_.Results })
$failed = @($results | Where-Object { $_.Status -ne 'PASS' })
$passed = $results.Count - $failed.Count
$logErrors = @($runs | ForEach-Object { $_.LogErrors })
$allScriptErrors = @($runs | ForEach-Object { $_.StartupErrors }) + @($results | ForEach-Object { $_.ScriptErrors })
$duration = Format-Elapsed ((Get-Date) - $RunStart)

$errorsFile = Join-Path $ResultDir 'errors.txt'
$errLines = @('# Script errors') + @($allScriptErrors | ForEach-Object { "[$(if ($_.Test) { $_.Test } else { 'startup' })] $($_.Text)" }) +
            @('', '# Antistasi Error log lines') + @($logErrors | ForEach-Object { "[$(if ($_.Test) { $_.Test } else { 'startup' })] $($_.Text)" })
Set-Content -Path $errorsFile -Value $errLines -Encoding UTF8
$runs | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $ResultDir 'results.json') -Encoding UTF8

Write-Host ''
Write-Host ('=' * 74) -ForegroundColor Cyan
$color = if ($failed.Count) { 'Red' } else { 'Green' }
Write-Host (' {0}   passed {1} / {2}   failed {3}   duration {4}' -f $(if ($failed.Count) { 'FAILED' } else { 'ALL PASSED' }), $passed, $results.Count, $failed.Count, $duration) -ForegroundColor $color
foreach ($run in $runs) {
    $o = if ($run.Outcome -eq 'done') { 'completed' } else { $run.Outcome }
    Write-Host ("   server run: {0} - {1}" -f $run.Label, $o) -ForegroundColor DarkGray
}
if ($failed.Count) {
    Write-Host ''
    Write-Host ' Failed tests:' -ForegroundColor Red
    foreach ($r in $failed) {
        Write-Host ('   x {0}  [{1}] {2}' -f $r.Name, $r.Group, $r.Status) -ForegroundColor Red
        if ($r.Message) { Write-Host "       $($r.Message)" }
        foreach ($a in @($r.Asserts | Select-Object -Skip 1 -First 5)) { Write-Host "       also: $a" -ForegroundColor DarkGray }
        foreach ($e in @($r.ScriptErrors | Where-Object { $_.Relevant } | Select-Object -First 3)) { Write-Host "       script error: $($e.Text)" -ForegroundColor DarkYellow }
    }
}
Write-Host ''
Write-Host (' Script errors in the RPT: {0} total, {1} from Antistasi/test files' -f $allScriptErrors.Count, @($allScriptErrors | Where-Object { $_.Relevant }).Count) -ForegroundColor DarkGray
Write-Host (' Antistasi Error log lines: {0}{1}' -f $logErrors.Count, $(if ($StrictLog) { '' } else { ' (not counted as failures, use -StrictLog)' })) -ForegroundColor DarkGray
Write-Host " Details: $ResultDir (results.json, errors.txt, RPT copies)" -ForegroundColor DarkGray
Write-Host ('=' * 74) -ForegroundColor Cyan

exit $(if ($failed.Count) { 1 } else { 0 })
