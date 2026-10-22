/*
    Records a failure on the running test when actual is not equal (isEqualTo) to expected.

    Arguments:
        0: ANY    - actual value
        1: ANY    - expected value
        2: STRING - what is compared, in words
        3: NUMBER - source line (ASSERT_EQ macro fills it), optional

    Return: BOOL - true when equal

    Maintainer: Shoter
*/
params ["_actual", "_expected", ["_message", "values differ"], ["_line", -1]];

private _ok = _actual isEqualTo _expected;
if (!_ok) then {
    [format ["%1: expected %2, got %3", _message, _expected, _actual], _line] call A3A_test_fnc_fail;
};
_ok;
