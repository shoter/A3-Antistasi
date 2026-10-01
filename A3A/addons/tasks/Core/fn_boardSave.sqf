/*
Maintainer: Shoter
    Returns the mission board in a form that can go into the save (JSON or profile namespace).
    Entries are copied; objects and sides in the mission arguments (radio tower, house, police station, bank,
    camp side) are replaced by hashmaps that A3A_tasks_fnc_boardRestore turns back into them.
    Missions already taken from the board are not on it, so they are not saved.

Arguments:
    None

Return Value:
    <ARRAY> Saved board entries, see A3A_tasks_fnc_boardGenerate

Scope: Server
Environment: Any
Public: No

Example:
    ["missionBoard", call A3A_tasks_fnc_boardSave] call A3A_fnc_setStatVariable;
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

if (isNil "A3A_missionBoard") exitWith { [] };

private _fnc_encode = {
    if (_this isEqualType objNull) exitWith { createHashMapFromArray [["obj", [typeOf _this, getPosATL _this]]] };
    if (_this isEqualType sideUnknown) exitWith { createHashMapFromArray [["side", str _this]] };
    if (_this isEqualType []) exitWith { _this apply { _x call _fnc_encode } };
    _this;
};

A3A_missionBoard apply {
    private _entry = +_x;
    _entry set ["args", (_x get "args") call _fnc_encode];
    _entry;
};
