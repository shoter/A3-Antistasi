/*
    City task: the enemy has mined a field on the edge of town and the locals want it cleared
    Every mine has to be removed (disarmed, detonated or blown up). Every player who took part
    gets 200 € per war level and the town's support for the rebels rises.

Maintainer: Shoter
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

// Don't use checkpoints for minor missions
params ["_params", "_checkpoint"];
_params params ["_marker", "_fieldPos", "_fieldRad", "_mineCount"];
Trace_1("Params: %1", _params);

private _task = createHashMap;

_task set ["_hintTitle", localize "STR_A3A_Tasks_minefield_title"];
_task set ["_marker", _marker];
_task set ["_fieldPos", _fieldPos];
_task set ["_endTime", time + 45*60];
_task set ["_participants", []];            // UIDs of players who came to the field

// Lay the mines. The enemy and the civilians know where they are, and the locals marked them for us
private _enemySide = sidesX getVariable _marker;
private _faction = Faction(_enemySide);
private _mineTypes = (_faction getOrDefault ["minefieldAPERS", []]) + (_faction getOrDefault ["minefieldAT", []]);
if (_mineTypes isEqualTo []) then { _mineTypes = ["APERSMine"] };
private _mines = [];
for "_i" from 1 to _mineCount do {
    private _mine = createMine [selectRandom _mineTypes, _fieldPos, [], _fieldRad];
    _enemySide revealMine _mine;
    civilian revealMine _mine;
    teamPlayer revealMine _mine;
    _mines pushBack _mine;
};
_task set ["_mines", _mines];
_task set ["_minesLeft", count _mines];

// Mark the field on the map
private _taskId = call FUNC(genTaskUID);
private _fieldMrk = createMarker ["task_minefield_" + _taskId, _fieldPos];
_fieldMrk setMarkerShape "ELLIPSE";
_fieldMrk setMarkerSize [_fieldRad + 5, _fieldRad + 5];
_fieldMrk setMarkerBrush "FDiagonal";
_fieldMrk setMarkerColor "ColorRed";
_task set ["_fieldMrk", _fieldMrk];

// Create the task
private _reward = 200 * tierWar;
_task set ["_reward", _reward];
private _displayTime = [((_task get "_endTime") - time) / 60] call FUNC(minutesFromNow);
private _taskDesc = format [localize "STR_A3A_Tasks_minefield_desc", _marker, count _mines, _displayTime, _reward];
[true, _taskId, [_taskDesc, _task get "_hintTitle"], _fieldPos, false, -1, false, "mine", true] call BIS_fnc_taskCreate;
_task set ["_taskId", _taskId];
[_taskId, "CREATED", markerPos _marker, 1300] call FUNC(taskNotifyNear);

_task set ["state", "s_clearField"];
_task set ["interval", 2];

Trace_1("Initial data: %1", _task);

_task set ["s_clearField", {
    private _fieldPos = _this get "_fieldPos";

    // Anyone who comes to the field counts as taking part, even if they die or leave before the end
    private _participants = _this get "_participants";
    {
        _participants pushBackUnique getPlayerUID _x;
    } forEach (call A3A_fnc_playableUnits inAreaArray [_fieldPos, 100, 100]);

    private _minesLeft = {alive _x} count (_this get "_mines");
    if (_minesLeft == 0) exitWith {
        _this set ["state", "s_success"]; false;
    };

    if (time > _this get "_endTime") exitWith {
        [_this get "_hintTitle", localize "STR_A3A_Tasks_minefield_timeout", _fieldPos, 300] call FUNC(hintNear);
        _this set ["state", "s_failure"]; false;
    };

    if (_minesLeft < _this get "_minesLeft") then {
        _this set ["_minesLeft", _minesLeft];
        [_this get "_hintTitle", format [localize "STR_A3A_Tasks_minefield_progress", _minesLeft], _fieldPos, 300] call FUNC(hintNear);
    };
    false;
}];

_task set ["s_success", {
    private _fieldPos = _this get "_fieldPos";
    private _reward = _this get "_reward";
    private _participants = _this get "_participants";

    // Pay everyone who took part and is still on the server
    private _paidPlayers = (call A3A_fnc_playableUnits) select { getPlayerUID _x in _participants };
    { [_reward, _x] call A3A_fnc_resourcesPlayer } forEach _paidPlayers;
    Info_2("Minefield cleared near %1, paid %2 players", _this get "_marker", count _paidPlayers);

    [10, _this get "_marker"] remoteExecCall ["A3A_fnc_citySupportChange", 2];

    private _successText = format [localize "STR_A3A_Tasks_minefield_success", _this get "_marker", _reward];
    if (_paidPlayers isNotEqualTo []) then {
        [_this get "_hintTitle", _successText] remoteExecCall ["A3A_fnc_customHint", _paidPlayers];
    };

    [_this get "_taskId", "SUCCEEDED", _fieldPos, 300] call FUNC(taskNotifyNear);
    [_this get "_taskId", "SUCCEEDED", false] call BIS_fnc_taskSetState;
    _this set ["state", "s_cleanup"]; false;
}];

_task set ["s_failure", {
    [_this get "_taskId", "FAILED", false] call BIS_fnc_taskSetState;
    _this set ["state", "s_cleanup"]; false;
}];

_task set ["s_cleanup", {
    deleteMarker (_this get "_fieldMrk");

    // Don't leave a forgotten minefield behind after a failure
    { deleteVehicle _x } forEach ((_this get "_mines") select { alive _x });

    (_this get "_taskId") spawn {
        sleep 600;
        [_this, true, true] call BIS_fnc_deleteTask;
    };
    true;       // delete the task
}];

_task;
