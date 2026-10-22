# Antistasi automated tests

Runs SQF tests inside a real Antistasi campaign on a local dedicated server. No players and no game client are needed.

From the repository root. `launch_tests.ps1` there passes every parameter on to `Tools\AutoTest\launch_tests.ps1`.

```powershell
.\launch_tests.ps1                       # build @A3A, run every test, print a summary
.\launch_tests.ps1 -Test smoke_* -NoBuild
.\launch_tests.ps1 -List                 # tests, their timeout, campaign setup and description
.\launch_tests.ps1 -Vanilla              # only @A3A, faster startup
.\launch_tests.ps1 -KeepServer -ShowInfo
```

Exit code: 0 when everything passed, 1 when a test failed, 2 when the build failed.

## What happens

1. `Tools\Builder\build.ps1` builds `@A3A` (skip with `-NoBuild`). The build refuses to run while an Arma server has the PBOs open.
2. Selected tests are grouped by campaign setup (map, new game or save, factions, params). Each group is one server run.
3. For each run, `addon\` and the group's tests are packed into `work\mod\@A3A_AutoTest` and loaded with `-serverMod`. The test addon never goes into `A3A\addons`, so it cannot end up in a release.
4. `arma3server_x64.exe` starts with `-autoInit` and its own profile in `work\server`. The generated `server.cfg` sets `loopback = true` (nobody can join) and `persistent = 1` (the mission runs without players).
5. The addon waits for the Antistasi setup monitor, starts the campaign itself (what the admin's setup dialog normally does), waits for `serverInitDone`, then runs the tests one by one.
6. The script follows the RPT live, shows progress and every result, then stops the server.

Results go to `work\results\<run id>`: `results.json`, `errors.txt` (script errors and Antistasi `Error` log lines, labelled with the test they happened in) and a copy of each RPT.

## Settings: where the server and profiles are

`launch_tests.ps1` and `install_server.ps1` read their paths from `autotest.settings.ps1` (committed defaults). After that they read `autotest.settings.local.ps1` next to it, which is git-ignored and holds your machine's values. A parameter on the command line wins over both.

| Setting | Committed default | Purpose |
|---|---|---|
| `ServerDir` | `work\arma3server` | Arma 3 dedicated server install. Point it at a server you already have, so there is only one copy. |
| `SteamCmdDir` | `work\steamcmd` | SteamCMD used by `install_server.ps1`. It is downloaded when missing. |
| `SteamUser` | empty | Steam account that owns Arma 3. Steam refuses anonymous downloads of the server (app 233780, 'No subscription'). `STEAM_USERNAME` in the environment wins. |
| `ModsFile` | empty (vanilla) | Mod list in the launcher format. `@A3A` from `buildConfig.json` is added when missing. |
| `WorkshopDir` | empty | Workshop content folder for the IDs in `ModsFile`. |
| `SaveProfile` | empty (no saves) | Server profile folder whose saves are copied fresh into `work\server` before every server run, for `@start: load` tests. The source is never written. |
| `Port` | `2402` | Test server port, different from your normal server. |

Example `autotest.settings.local.ps1` that reuses the install under `C:\games\A3`:

```powershell
$Settings.ServerDir   = 'C:\games\A3\Arma3\A3Master'
$Settings.SteamCmdDir = 'C:\games\A3\Steam'
$Settings.SteamUser   = 'mysteamname'
$Settings.ModsFile    = 'C:\games\A3\configs\Antistasi Debug\mods.txt'
$Settings.WorkshopDir = 'C:\games\A3\Steam\steamapps\workshop\content\107410'
$Settings.SaveProfile = 'C:\games\A3\configs\Antistasi Debug\Users\AntistasiServer'
```

`install_server.ps1` installs or updates the server in `ServerDir` with SteamCMD. It keeps the installed branch, for example `creatordlc`. Locally SteamCMD uses its cached login, or asks for the password once.

The difficulty settings are committed in `server\A3ATest.Arma3Profile`, so local runs and CI play on the same difficulty.

Other parameters: `-StartupTimeoutMinutes` (default 30, from server launch to the first test) and `-StrictLog` (also fail a test when Antistasi logs an `Error` line during it).

`work\` is git-ignored: the server when `ServerDir` is left at its default, the profile and save copies, RPTs and packed PBOs.

## Writing a test

A test is `tests\<name>.sqf`. It runs on the server in a scheduled script after server init, so `sleep` and `waitUntil` work. Files starting with `_` run only when a `-Test` pattern starting with `_` selects them. `tests\_selftest_*.sqf` check the harness itself: after changing `launch_tests.ps1` or `addon\`, run `-Test _selftest_* -Vanilla`. One test passes and the others must come out FAIL, FAIL, TIMEOUT and NOT RUN.

```sqf
// @description: Rebel HR is positive on a new game
// @timeout: 60
// @start: new
// @world: Altis
#include "\x\A3A_autotest\test.hpp"

private _hr = server getVariable ["hr", -1];
ASSERT(_hr > 0, "rebel HR is positive");
ASSERT_EQ(A3A_startupState, "completed", "startup state");

private _spawned = WAIT_UNTIL(count allUnits > 50, 30);
if (!_spawned) exitWith { FAIL("units did not spawn within 30 s") };
INFO("units: " + str count allUnits);
```

Header lines (all optional):

| Header | Meaning |
|---|---|
| `// @description: text` | Shown by `-List`. |
| `// @timeout: 120` | Seconds before the test is terminated (TIMEOUT). Default 120. |
| `// @start: new` or `// @start: load <gameID>` | New campaign, or load a save from the copied `-SaveProfile`. When the ID is missing, the run stops with a FATAL that lists the IDs found. |
| `// @world: Altis` | Map. The mission template is `Antistasi_<world>.<world>`. |
| `// @factions: occ,inv,reb,civ` | Template class names for a new game. Empty entries use the setup dialog defaults for the map and modset. |
| `// @param: name=value` | Mission param override for a new game (`A3A\addons\core\Params.hpp` names), repeatable. |

Tests with the same `@start`, `@world`, `@factions` and `@param` share one server run, in name order, so a test can see what earlier tests in its run left behind. Clean up what you spawn.

Helpers (`test.hpp` macros, or call the functions directly):

| Macro | Function | |
|---|---|---|
| `ASSERT(cond, msg)` | `A3A_test_fnc_assert` | Records a failure when `cond` is not `true`. The test keeps running. |
| `ASSERT_EQ(actual, expected, msg)` | `A3A_test_fnc_assertEqual` | Compares with `isEqualTo` and prints both values on failure. |
| `FAIL(msg)` | `A3A_test_fnc_fail` | Records a failure. Combine it with `exitWith` to stop the test. |
| `INFO(msg)` | `A3A_test_fnc_info` | Note kept in `results.json`, printed with `-ShowInfo`. |
| `WAIT_UNTIL(cond, timeout)` | `A3A_test_fnc_waitUntil` | Waits for the condition and returns `false` on timeout. |

Arma's preprocessor splits macro arguments on commas, including commas inside `[]`. Put arrays and `format [...]` calls in a local variable first, or call the function form.

Statuses:

- **PASS**: the test finished and no assertion failed.
- **FAIL**: an assertion failed, or a script error from an Antistasi or test file was logged while the test ran.
- **ERROR**: the test script stopped before its end (usually a script error) or did not compile.
- **TIMEOUT**: the test was still running after its timeout.
- **NOT RUN**: the server run was aborted first. The summary says why and prints the last RPT lines.

Each server run also gets the check `[rpt] no Antistasi script errors during startup`. It fails when a script error from an Antistasi file appears in the RPT outside a test.

## GitHub Actions

`.github/workflows/autotest.yml` runs the tests on every pull request into `unstable` that touches `A3A/`, `Tools/AutoTest/`, `Tools/Builder/` or the workflow. You can also start it by hand from the Actions tab. It:

- uses a `windows-latest` runner
- installs the Arma 3 dedicated server into the default `ServerDir` with `install_server.ps1`, cached weekly (about 5 GB)
- logs SteamCMD in with the cached session in the `STEAM_USERNAME` and `STEAM_CONFIG_VDF` secrets, the same ones the Workshop publish workflow uses (anonymous login is refused)
- builds `@A3A`
- runs `launch_tests.ps1` with the committed settings: vanilla, no saves, the committed difficulty

The same workflow gates the Steam Workshop publish: `publishBranchToSteam.yml` calls it as a `test` job on every push to `unstable`, and builds and uploads only when it passes. A failing test means that push is not published.

Failed tests show up as error annotations and in the job summary table. The `autotest-results` artifact holds `results.json`, `errors.txt` and the RPTs.

There are no saves in CI, so tests with `@start: load` cannot pass there. GitHub does not give secrets to pull requests from forks, so the workflow only works for branches of this repository. When `STEAM_CONFIG_VDF` expires, regenerate it as described in `publishBranchToSteam.yml`.

## Limits

- Server side only: dialogs, client scripts and player actions are not covered.
- No players means Antistasi spawns little on its own. Spawn units, or call the functions under test directly.
- Startup with the full modset takes several minutes per server run. `-Vanilla` is much quicker for logic that does not depend on mod content.
