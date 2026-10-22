/*
    Logs an informational line for the running test; launch_tests.ps1 shows it with -ShowInfo
    and keeps it in the results file.

    Arguments:
        0: STRING - message

    Maintainer: Shoter
*/
params ["_message"];

private _name = if (isNil "A3A_test_ctx") then { "" } else { A3A_test_ctx get "name" };
["INFO", [_name, _message]] call A3A_test_fnc_log;
