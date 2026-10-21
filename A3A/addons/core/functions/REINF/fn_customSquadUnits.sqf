/*
Maintainer: Shoter
    Unit types of a custom squad from the squad composer, as recruited from the Recruit Squad dialog:
    the squad leader first, then the chosen soldiers grouped by type.

Arguments:
    <NUMBER> Custom squad index, 0 for Custom 1 or 1 for Custom 2
    <ARRAY> Unit counts to use instead of the saved ones, [[unit key, count], ...] (optional)

Return Value:
    <ARRAY<STRING>> Rebel unit types, ready for A3A_fnc_addFIAsquadHC

Scope: Any
Environment: Any
Public: No
Dependencies:
    A3A_customSquads, A3A_faction_reb

Example:
    private _units = [0] call A3A_fnc_customSquadUnits;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_index", 0, [0]], "_counts"];

if (isNil "_counts") then { _counts = (A3A_customSquads param [_index, ["", []]]) # 1 };

private _units = [FactionGet(reb,"unitSL")];
{
    _x params ["_key", "_count"];
    private _type = FactionGet(reb,_key);
    if (isNil "_type") then { continue };
    for "_i" from 1 to _count do { _units pushBack _type };
} forEach _counts;

_units
