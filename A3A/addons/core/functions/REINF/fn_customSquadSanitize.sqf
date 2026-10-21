/*
Maintainer: Shoter
    Cleans a custom squad composition from the squad composer or from a save.
    The abbreviation is upper-cased and keeps up to 5 letters and digits. The unit counts keep only the garrison unit
    types in A3A_customSquadKeys, in that order, and are cut so that the squad, its squad leader included, stays within
    A3A_customSquadMaxSize soldiers.

Arguments:
    <STRING> Abbreviation shown in the high command bar
    <ARRAY> Unit counts, [[unit key, count], ...]
    <STRING> Abbreviation to use when nothing is left of the given one (default "")

Return Value:
    <ARRAY> [abbreviation, [[unit key, count], ...]], unit types with no soldiers are left out

Scope: Any
Environment: Any
Public: No
Dependencies:
    A3A_customSquadKeys, A3A_customSquadMaxSize

Example:
    ["abc!", [["unitRifle", 3]], "CS1"] call A3A_fnc_customSquadSanitize; // ["ABC", [["unitRifle", 3]]]
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_abbr", "", [""]], ["_counts", [], [[]]], ["_defaultAbbr", "", [""]]];

// 0-9 and A-Z only
private _chars = (toArray toUpper _abbr) select { (_x >= 48 && _x <= 57) || (_x >= 65 && _x <= 90) };
_abbr = toString (_chars select [0, 5]);
if (_abbr == "") then { _abbr = _defaultAbbr };

private _wanted = createHashMap;
{
    if (_x isEqualTypeArray ["", 0]) then { _wanted set [_x # 0, (_wanted getOrDefault [_x # 0, 0]) + (0 max floor (_x # 1))] };
} forEach _counts;

private _pairs = [];
private _total = 1;                                         // the squad leader
{
    private _count = (_wanted getOrDefault [_x, 0]) min (A3A_customSquadMaxSize - _total);
    if (_count > 0) then {
        _pairs pushBack [_x, _count];
        _total = _total + _count;
    };
} forEach A3A_customSquadKeys;

[_abbr, _pairs]
