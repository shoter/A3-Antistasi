/*
    Runs the tests listed in run_config.sqf one after another and logs a RESULT line for each.

    Each test is \x\A3A_autotest\tests\<name>.sqf, run in its own scheduled script.
    Status:
        PASS    - script finished, no failed assertion
        FAIL    - script finished with at least one failed assertion
        ERROR   - script stopped before its end (usually a script error, see the RPT) or did not compile
        TIMEOUT - script still running after its timeout, terminated

    Arguments:
        0: ARRAY - [[name, timeoutSeconds], ...]

    Maintainer: Shoter
*/
params ["_tests"];

private _count = count _tests;
["PLAN", [_count, (_tests apply { _x#0 }) joinString ","]] call A3A_test_fnc_log;

private _passed = 0;
{
    _x params ["_name", ["_timeout", 120]];
    private _index = _forEachIndex + 1;
    ["BEGIN", [_index, _count, _name]] call A3A_test_fnc_log;

    A3A_test_ctx = createHashMapFromArray [["name", _name], ["failures", []], ["finished", false]];
    private _path = format ["\x\A3A_autotest\tests\%1.sqf", _name];
    private _status = "PASS";
    private _message = "";
    private _start = diag_tickTime;

    private _code = if (fileExists _path) then { compile preprocessFileLineNumbers _path } else { nil };
    if (isNil "_code" || {_code isEqualTo {}}) then {
        _status = "ERROR";
        _message = format ["could not load or compile %1", _path];
    } else {
        private _handle = [_code] spawn {
            params ["_code"];
            call _code;
            A3A_test_ctx set ["finished", true];
        };
        waitUntil { sleep 0.25; scriptDone _handle || diag_tickTime - _start > _timeout };

        private _failures = A3A_test_ctx get "failures";
        switch (true) do {
            case (!scriptDone _handle): {
                terminate _handle;
                _status = "TIMEOUT";
                _message = format ["still running after %1 s", _timeout];
            };
            case (!(A3A_test_ctx get "finished")): {
                _status = "ERROR";
                _message = "test script stopped before its end, check the script errors in the RPT";
            };
            case (_failures isNotEqualTo []): {
                _status = "FAIL";
                _message = _failures#0;
                if (count _failures > 1) then { _message = _message + format [" (+%1 more)", count _failures - 1] };
            };
        };
    };

    if (_status == "PASS") then { _passed = _passed + 1 };
    ["RESULT", [_index, _name, _status, (round ((diag_tickTime - _start) * 10)) / 10, _message]] call A3A_test_fnc_log;
} forEach _tests;

A3A_test_ctx = nil;
["DONE", [_passed, _count - _passed]] call A3A_test_fnc_log;
