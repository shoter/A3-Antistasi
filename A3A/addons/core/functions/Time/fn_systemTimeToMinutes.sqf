/*
Maintainer: Shoter
    Converts a systemTime or systemTimeUTC array into whole minutes since 2020-01-01 00:00, ignoring seconds.
    Minutes keep the value exact in Arma's 32-bit floats until 2051, whereas seconds would already round today.
    Used to compare timestamps and to work out the server's offset from UTC.

Arguments:
    <ARRAY> [year, month, day, hour, minute, ...] as returned by systemTime, extra elements are ignored

Return Value:
    <NUMBER> Minutes since 2020-01-01 00:00 in the same clock as the input

Scope: Any
Environment: Any
Public: Yes
Dependencies: None

Example:
    [systemTimeUTC] call A3A_fnc_systemTimeToMinutes;
    ([systemTime] call A3A_fnc_systemTimeToMinutes) - ([systemTimeUTC] call A3A_fnc_systemTimeToMinutes);  // local offset from UTC in minutes
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_time", [], [[]]]];
_time params [["_year", 2020, [0]], ["_month", 1, [0]], ["_day", 1, [0]], ["_hour", 0, [0]], ["_minute", 0, [0]]];

// Days from civil date (Howard Hinnant's algorithm), counted from 1970-01-01, then rebased to 2020-01-01
private _y = _year - ([0, 1] select (_month <= 2));
private _era = floor (_y / 400);
private _yoe = _y - _era * 400;
private _mp = (_month + 9) mod 12;                                   // March is month 0
private _doy = floor ((153 * _mp + 2) / 5) + _day - 1;
private _doe = _yoe * 365 + floor (_yoe / 4) - floor (_yoe / 100) + _doy;
private _days = _era * 146097 + _doe - 719468 - 18262;

_days * 1440 + _hour * 60 + _minute
