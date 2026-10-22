/*
    Records a failure on the running test. The test keeps running; use exitWith to stop it.

    Arguments:
        0: STRING - failure message
        1: NUMBER - source line (FAIL macro fills it), optional

    Maintainer: Shoter
*/
params ["_message", ["_line", -1]];

if (_line >= 0) then { _message = format ["%1 (line %2)", _message, _line] };
private _name = if (isNil "A3A_test_ctx") then { "" } else {
    (A3A_test_ctx get "failures") pushBack _message;
    A3A_test_ctx get "name";
};
["ASSERT", [_name, _message]] call A3A_test_fnc_log;
