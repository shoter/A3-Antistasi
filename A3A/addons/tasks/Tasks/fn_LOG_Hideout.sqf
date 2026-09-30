/*
Maintainer: Shoter
    Abandoned collaborator hideout task. A collaborator has fled his house in a hurry and left his papers
    and a crate of loot behind. The map only shows a search circle that has the house somewhere inside it.
    Nobody guards the place: find the house and take the papers (a medium intel roll for the side he worked for).
    The crate is filled like an enemy loot crate and is the players' to empty or haul away.
    Every player who took part (came within 100m of the house) gets 200 €. No faction money, no town support.
    The task fails when time runs out or the house is destroyed before the papers are taken.

    Runs in the A3A_tasks_fnc_runTask framework: this file builds the task hashmap and its state functions.

Arguments:
    <ARRAY> Task params from FUNC(LOG_Hideout_p): [house position ATL, house object, enemy side, circle centre, circle radius]
    <ANY> Checkpoint data, unused (task is not saved)

Return Value:
    <HASHMAP> Task

Scope: Server
Environment: Scheduled
Public: No
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

#define REWARD 200
#define PARTICIPANT_RADIUS 100
#define DURATION (90*60)

params ["_params", "_checkpoint"];
_params params ["_housePos", "_house", "_side", "_center", "_radius"];
Trace_1("Params: %1", _params);

private _faction = Faction(_side);

private _task = createHashMap;
_task set ["_hintTitle", localize "STR_A3A_Tasks_LOG_Hideout_title"];
_task set ["_housePos", _housePos];
_task set ["_house", _house];
_task set ["_side", _side];
_task set ["_endTime", time + DURATION];
_task set ["_participants", []];            // UIDs of players who came near the house

// Crate on the ground floor, papers on a table somewhere else in the house
private _positions = (_house buildingPos -1) select { !surfaceIsWater _x };
private _groundPositions = _positions select { _x # 2 < 1 };
private _cratePos = selectRandom _groundPositions;
private _otherPositions = _positions select { _x distance _cratePos > 2.5 };
if (_otherPositions isEqualTo []) then { _otherPositions = _positions - [_cratePos] };
private _intelPos = selectRandom _otherPositions;

private _crate = createVehicle [_faction get "ammobox", [0, 0, 0], [], 0, "CAN_COLLIDE"];
_crate setDir random 360;
_crate setPosATL (_cratePos vectorAdd [0, 0, 0.05]);
// Otherwise when destroyed, ammoboxes sink 100m underground and are never cleared up
_crate addEventHandler ["Killed", { [_this#0] spawn { sleep 10; deleteVehicle (_this#0) } }];
[_crate] spawn A3A_fnc_fillLootCrate;
[_crate] call A3A_Logistics_fnc_addLoadAction;
_task set ["_crate", _crate];
_task set ["_cratePos", _cratePos];

private _table = createVehicle ["Land_CampingTable_small_F", [0, 0, 0], [], 0, "CAN_COLLIDE"];
_table setDir random 360;
_table setPosATL _intelPos;
_table enableSimulationGlobal false;

(_faction get "placeIntel_itemMedium") params ["_intelType", "_azimuth"];
private _intel = createVehicle [_intelType, [0, 0, 0], [], 0, "CAN_COLLIDE"];
_intel setDir (getDir _table + _azimuth);
// Bottom of the papers on the table top
_intel setPosWorld (_table modelToWorldWorld [0, 0, ((boundingBoxReal _table) # 1 # 2) - ((boundingBoxReal _intel) # 0 # 2)]);
_intel enableSimulationGlobal false;
_intel allowDamage false;
_task set ["_intel", _intel];
_task set ["_objects", [_table, _intel]];

// The server picks up A3A_hideoutTakenBy on its next tick
[
    _intel,
    localize "STR_A3A_Tasks_LOG_Hideout_takeAction",
    "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa",
    "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa",
    "(_this distance _target < 3) and (isNil {_target getVariable 'A3A_hideoutTakenBy'})",
    "_caller distance _target < 3",
    {},
    {},
    { _target setVariable ["A3A_hideoutTakenBy", _caller, true] },
    {},
    [],
    5,
    10,
    true,
    false
] remoteExec ["BIS_fnc_holdActionAdd", 0, _intel];

// The map only shows a circle somewhere around the house
private _taskId = "LOG" + str A3A_taskCount;
private _areaMrk = createMarker ["A3A_hideoutArea_" + _taskId, _center];
_areaMrk setMarkerShape "ELLIPSE";
_areaMrk setMarkerSize [_radius, _radius];
_areaMrk setMarkerBrush "FDiagonal";
_areaMrk setMarkerColor "ColorOrange";
_areaMrk setMarkerAlpha 0.6;
_task set ["_areaMrk", _areaMrk];

private _nearTown = [citiesX, _housePos] call BIS_fnc_nearestPosition;
private _displayTime = [DURATION / 60] call FUNC(minutesFromNow);
private _taskDesc = format [localize "STR_A3A_Tasks_LOG_Hideout_desc", _faction get "name", [_nearTown] call A3A_fnc_localizar, _displayTime, REWARD];
[[teamPlayer, civilian], _taskId, [_taskDesc, _task get "_hintTitle", _areaMrk], _center, false, 0, true, "search", true] call BIS_fnc_taskCreate;
[_taskId, "LOG", "CREATED"] remoteExecCall ["A3A_fnc_taskUpdate", 2];
_task set ["_taskId", _taskId];

_task set ["state", "s_search"];
_task set ["interval", 2];

Trace_1("Initial data: %1", _task);


//////////////////////
// Helper functions //
//////////////////////

// Spawned on the server at cleanup: removes the props once no rebel is around any more
_task set ["_fnc_despawn", {
    params ["_housePos", "_objects", "_crate", "_cratePos"];
    waitUntil { sleep 30; !([distanceSPWN, 1, _housePos, teamPlayer] call A3A_fnc_distanceUnits) };
    { deleteVehicle _x } forEach _objects;
    // Leave the crate alone if the players took it with them
    if (!isNull _crate and { _crate distance2d _cratePos < 5 and isNull attachedTo _crate }) then { deleteVehicle _crate };
}];


/////////////////////
// State functions //
/////////////////////

_task set ["s_search", {
    private _housePos = _this get "_housePos";
    private _intel = _this get "_intel";

    // Anyone who comes near the house counts as taking part, even if they die or leave before the end
    private _participants = _this get "_participants";
    {
        _participants pushBackUnique getPlayerUID _x;
    } forEach (call A3A_fnc_playableUnits inAreaArray [_housePos, PARTICIPANT_RADIUS, PARTICIPANT_RADIUS]);

    if (!isNull _intel and { !isNil { _intel getVariable "A3A_hideoutTakenBy" } }) exitWith {
        _this set ["state", "s_success"]; false;
    };

    // Papers lost with the house
    if (!alive (_this get "_house") or isNull _intel) exitWith {
        [_this get "_hintTitle", localize "STR_A3A_Tasks_LOG_Hideout_destroyed", _housePos, 1000] call FUNC(hintNear);
        _this set ["state", "s_failure"]; false;
    };

    // Out of time. Keep going while players are still at it, up to 20 extra minutes
    private _endTime = _this get "_endTime";
    if (time > _endTime and { time > _endTime + 20*60 or call A3A_fnc_playableUnits inAreaArray [_housePos, 300, 300] isEqualTo [] }) exitWith {
        [_this get "_hintTitle", localize "STR_A3A_Tasks_LOG_Hideout_timeout", _housePos, 1000] call FUNC(hintNear);
        _this set ["state", "s_failure"]; false;
    };
    false;
}];

_task set ["s_success", {
    private _housePos = _this get "_housePos";
    private _intel = _this get "_intel";
    private _taker = _intel getVariable "A3A_hideoutTakenBy";
    if (isPlayer _taker) then { (_this get "_participants") pushBackUnique getPlayerUID _taker };
    deleteVehicle _intel;

    ["Medium", _this get "_side"] call A3A_fnc_selectIntel;

    // Pay everyone who took part and is still on the server
    private _participants = _this get "_participants";
    private _paidPlayers = (call A3A_fnc_playableUnits) select { getPlayerUID _x in _participants };
    { [REWARD, _x] call A3A_fnc_resourcesPlayer } forEach _paidPlayers;
    Info_2("Collaborator hideout at %1 searched, paid %2 players", _housePos, count _paidPlayers);

    if (_paidPlayers isNotEqualTo []) then {
        [_this get "_hintTitle", format [localize "STR_A3A_Tasks_LOG_Hideout_success", REWARD]] remoteExecCall ["A3A_fnc_customHint", _paidPlayers];
    };

    [_this get "_taskId", "SUCCEEDED", _housePos, 500] call FUNC(taskNotifyNear);
    [_this get "_taskId", "LOG", "SUCCEEDED"] call A3A_fnc_taskSetState;
    _this set ["state", "s_cleanup"]; false;
}];

_task set ["s_failure", {
    [_this get "_taskId", "LOG", "FAILED"] call A3A_fnc_taskSetState;
    _this set ["state", "s_cleanup"]; false;
}];

_task set ["s_cleanup", {
    deleteMarker (_this get "_areaMrk");
    [_this get "_housePos", _this get "_objects", _this get "_crate", _this get "_cratePos"] spawn (_this get "_fnc_despawn");
    [_this get "_taskId", "LOG", 1200] spawn A3A_fnc_taskDelete;
    true;       // delete the task
}];

_task;
