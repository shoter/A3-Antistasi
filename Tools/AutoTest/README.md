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

## Defaults and where they come from

| Parameter | Default | Purpose |
|---|---|---|
| `-ModsFile` | `C:\games\A3\configs\Antistasi Debug\mods.txt` | Mod list, same format as the server launcher. `@A3A` from `buildConfig.json` is added when missing. |
| `-SaveProfile` | `C:\games\A3\configs\Antistasi Debug\Users\AntistasiServer` | Copied fresh into `work\server` before every server run: the difficulty settings and the saves for `@start: load`. The source is never written. |
| `-ServerDir` | `C:\games\A3\Arma3\A3Master` | Dedicated server install. |
| `-Port` | `2402` | Different from the normal server, so both can run at once (not with `-NoBuild` off: the build needs the PBOs free). |
| `-StartupTimeoutMinutes` | `30` | From server launch until the first test starts. |
| `-StrictLog` | off | Also fail a test when Antistasi logs an `Error` line during it. |

`work\` is git-ignored. Everything copied from the Steam or server install, and everything the server writes, stays there.

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

## Limits

- Server side only: dialogs, client scripts and player actions are not covered.
- No players means Antistasi spawns little on its own. Spawn units, or call the functions under test directly.
- Startup with the full modset takes several minutes per server run. `-Vanilla` is much quicker for logic that does not depend on mod content.
