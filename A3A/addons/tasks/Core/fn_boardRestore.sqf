/*
Maintainer: Shoter
    Puts the saved mission board back, from the data written by A3A_tasks_fnc_boardSave.
    Objects are found again by type near their saved position; an entry whose object is gone, or whose task
    no longer exists, is dropped. Entries get fresh ids. Missions that no longer fit are dropped later by
    A3A_tasks_fnc_boardUpdate, like on any refresh.

Arguments:
    <ARRAY> Saved board entries

Return Value:
    <NUMBER> Entries restored

Scope: Server
Environment: Any
Public: No

Example:
    [A3A_missionBoardSaved] call A3A_tasks_fnc_boardRestore;
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

#define TASKS_CFG (configFile/"A3A"/"Tasks")

params [["_saved", [], [[]]]];

private _sides = createHashMapFromArray [["WEST", west], ["EAST", east], ["GUER", independent], ["CIV", civilian]];
private _failed = false;

private _fnc_decode = {
    if (_this isEqualType createHashMap) exitWith {
        if ("side" in _this) exitWith { _sides getOrDefault [_this get "side", sideUnknown] };
        (_this getOrDefault ["obj", ["", [0, 0, 0]]]) params ["_type", "_pos"];
        private _obj = if (_type == "") then { objNull } else { nearestObjects [_pos, [_type], 10, true] param [0, objNull] };
        if (isNull _obj) then { _failed = true };
        _obj;
    };
    if (_this isEqualType []) exitWith { _this apply { _x call _fnc_decode } };
    _this;
};

{
    if !(_x isEqualType createHashMap) then { continue };
    private _entry = _x;
    private _task = _entry getOrDefault ["task", ""];
    if (!isClass (TASKS_CFG >> _task) or { isNil { missionNamespace getVariable (_entry getOrDefault ["func", ""]) } }) then {
        Info_1("Mission board: dropping saved %1, the task no longer exists", _task);
        continue;
    };
    _failed = false;
    private _args = (_entry getOrDefault ["args", []]) call _fnc_decode;
    if (_failed) then {
        Info_2("Mission board: dropping saved %1 at %2, its object was not found", _task, _entry get "marker");
        continue;
    };
    _entry set ["args", _args];
    A3A_missionBoardUID = A3A_missionBoardUID + 1;
    _entry set ["id", A3A_missionBoardUID];
    A3A_missionBoard pushBack _entry;
} forEach _saved;

Info_1("Mission board: %1 saved missions restored", count A3A_missionBoard);
count A3A_missionBoard;
