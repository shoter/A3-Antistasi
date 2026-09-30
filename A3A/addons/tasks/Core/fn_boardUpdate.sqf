/*
Maintainer: Shoter
    Refreshes the mission board: drops missions that no longer fit, retires a few random ones and posts new ones.
    New missions go to random categories that still have room (at most 10 missions per category).
    Shares the A3A_taskRequestInProgress lock with mission starts, so a mission can't be taken while the board changes.

Arguments:
    <NUMBER> Missions to post [DEFAULT = 0]
    <NUMBER> Random missions to retire first [DEFAULT = 0]
    <NUMBER> Afterwards, top every category up to this many missions [DEFAULT = 0]

Return Value:
    <NUMBER> Missions posted

Scope: Server
Environment: Scheduled
Public: No

Example:
    [3, 1 + floor random 2] call A3A_tasks_fnc_boardUpdate;       // regular refresh
    [0, 0, 2] call A3A_tasks_fnc_boardUpdate;                     // fresh board
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

#define BOARD_CATEGORIES ["AS", "CONVOY", "DES", "CON", "LOG", "SUPP", "RES"]
#define BOARD_MAX_PER_CATEGORY 10

if (!isServer) exitWith { Error("Server-only function miscalled"); 0 };

params [["_addCount", 0], ["_removeCount", 0], ["_minPerCategory", 0]];

// Check and take the lock unscheduled, so two scripts can't both take it
private _locked = false;
waitUntil {
    isNil { if (isNil "A3A_taskRequestInProgress") then { A3A_taskRequestInProgress = true; _locked = true } };
    _locked;
};

private _fnc_countOf = {
    params ["_category"];
    { (_x get "category") == _category } count A3A_missionBoard;
};

// Missions whose location was taken, target destroyed etc.
A3A_missionBoard = A3A_missionBoard select { ([_x] call FUNC(boardValidate)) != "gone" };

for "_i" from 1 to (_removeCount min count A3A_missionBoard) do {
    A3A_missionBoard deleteAt floor random count A3A_missionBoard;
};

private _added = 0;
for "_i" from 1 to _addCount do {
    private _open = BOARD_CATEGORIES select { ([_x] call _fnc_countOf) < BOARD_MAX_PER_CATEGORY };
    while { _open isNotEqualTo [] } do {
        private _entry = [_open deleteAt floor random count _open] call FUNC(boardGenerate);
        if (_entry isEqualType createHashMap) exitWith {
            A3A_missionBoard pushBack _entry;
            _added = _added + 1;
        };
    };
};

{
    private _category = _x;
    for "_i" from ([_category] call _fnc_countOf) + 1 to (_minPerCategory min BOARD_MAX_PER_CATEGORY) do {
        private _entry = [_category] call FUNC(boardGenerate);
        if (_entry isEqualType false) exitWith {};
        A3A_missionBoard pushBack _entry;
        _added = _added + 1;
    };
} forEach BOARD_CATEGORIES;

call FUNC(boardPublish);
Info_2("Mission board updated, %1 missions posted, %2 on the board", _added, count A3A_missionBoard);

A3A_taskRequestInProgress = nil;
_added;
