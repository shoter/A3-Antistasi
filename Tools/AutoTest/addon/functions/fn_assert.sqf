/*
    Records a failure on the running test when the condition is not true. The test keeps running.

    Arguments:
        0: BOOL   - condition
        1: STRING - what was expected, in words
        2: NUMBER - source line (ASSERT macro fills it), optional

    Return: BOOL - the condition

    Maintainer: Shoter
*/
params ["_condition", ["_message", "assertion failed"], ["_line", -1]];

if (isNil "_condition") exitWith {
    [_message + " (condition was nil, undefined variable?)", _line] call A3A_test_fnc_fail;
    false;
};
private _ok = _condition isEqualTo true;
if (!_ok) then {
    [_message, _line] call A3A_test_fnc_fail;
};
_ok;
