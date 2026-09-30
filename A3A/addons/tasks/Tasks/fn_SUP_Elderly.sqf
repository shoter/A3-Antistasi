/*
Maintainer: Shoter
    Elderly supplies task. An elder lives in a lone house outside a town and can no longer get
    to the shops. A supply crate appears at HQ; bring it to the house.
    There is no deadline and no enemy reaction: nobody is spawned or alerted by this task.
    There is no pay either, only town support. The task fails if the elder dies or the crate is lost.

    Runs in the A3A_tasks_fnc_runTask framework: this file builds the task hashmap and its state functions.

Arguments:
    <ARRAY> Task params from FUNC(SUP_Elderly_p): [town marker, house object]
    <ANY> Checkpoint data, unused (task is not saved)

Return Value:
    <HASHMAP> Task

Scope: Server
Environment: Scheduled
Public: No
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

#define SUPPORT_GAIN 10
#define SUPPORT_LOSS -5
#define DELIVERY_RADIUS 25

params ["_params", "_checkpoint"];
_params params ["_city", "_house"];
Trace_1("Params: %1", _params);

private _task = createHashMap;
_task set ["_hintTitle", localize "STR_A3A_Tasks_SUP_Elderly_title"];
_task set ["_city", _city];
_task set ["_house", _house];

// Supply crate at HQ, same as the city supplies task
private _hqPos = getMarkerPos respawnTeamPlayer;
private _boxPos = _hqPos findEmptyPosition [1, 75, "C_Van_01_box_F"];
if (_boxPos isEqualTo []) then { _boxPos = _hqPos findEmptyPosition [1, 75, "Land_FoodSacks_01_cargo_brown_F"] };
if (_boxPos isEqualTo []) then { _boxPos = _hqPos getPos [75 * sqrt random 1, random 360] };
private _box = "Land_FoodSacks_01_cargo_brown_F" createVehicle _boxPos;
_box enableRopeAttach true;
_box allowDamage false;
[_box] call A3A_Logistics_fnc_addLoadAction;
[_box, teamPlayer] call A3A_fnc_AIVEHinit;
[_box, "Supply Box"] spawn A3A_fnc_inmuneConvoy;
_task set ["_box", _box];

// The elder, on the ground floor if the house has one
private _positions = _house buildingPos -1;
private _groundPositions = _positions select { _x # 2 < 1 };
private _elderPos = selectRandom ([_positions, _groundPositions] select (_groundPositions isNotEqualTo []));
private _group = createGroup [civilian, true];
private _elder = [_group, FactionGet(civ, "unitMan"), _elderPos, [], 0, "CAN_COLLIDE"] call A3A_fnc_createUnit;
removeAllWeapons _elder;
_elder setDir (_house getDir _elderPos);
_elder disableAI "PATH";
_elder disableAI "FSM";
_elder disableAI "AUTOCOMBAT";
_elder allowFleeing 0;
_group setBehaviourStrong "CARELESS";
_task set ["_elder", _elder];

// Task. Locks the support category like the other SUPP tasks.
private _taskId = "SUPP" + str A3A_taskCount;
private _taskDesc = format [localize "STR_A3A_Tasks_SUP_Elderly_desc", [_city] call A3A_fnc_localizar];
[[teamPlayer, civilian], _taskId, [_taskDesc, _task get "_hintTitle", ""], getPosATL _house, false, 0, true, "Heal", true] call BIS_fnc_taskCreate;
[_taskId, "SUPP", "CREATED"] remoteExecCall ["A3A_fnc_taskUpdate", 2];
_task set ["_taskId", _taskId];

_task set ["state", "s_waitForDelivery"];
_task set ["interval", 2];

Trace_1("Initial data: %1", _task);


/////////////////////
// State functions //
/////////////////////

_task set ["s_waitForDelivery", {
    private _box = _this get "_box";
    private _elder = _this get "_elder";
    private _house = _this get "_house";

    if (!alive _elder) exitWith { _this set ["state", "s_elderDead"]; false };
    if (isNull _box) exitWith { _this set ["state", "s_boxLost"]; false };

    // Crate unloaded at the house
    if ((_box distance2d _house) min (_box distance2d _elder) > DELIVERY_RADIUS) exitWith {false};
    if (!isNull attachedTo _box or !isNull ropeAttachedTo _box or !isNull isVehicleCargo _box) exitWith {false};

    // Someone from our side is there to hand it over. Undercover players count, so no canFight here.
    private _nearUnits = allUnits inAreaArray [getPosATL _box, 30, 30];
    if (_nearUnits findIf { alive _x and { side group _x == teamPlayer } and { !(_x getVariable ["incapacitated", false]) } } == -1) exitWith {false};

    _this set ["state", "s_success"]; false;
}];

_task set ["s_success", {
    private _city = _this get "_city";
    private _box = _this get "_box";

    [SUPPORT_GAIN, _city] remoteExecCall ["A3A_fnc_citySupportChange", 2];

    private _hintStr = format [localize "STR_A3A_Tasks_SUP_Elderly_delivered", [_city] call A3A_fnc_localizar];
    [_this get "_hintTitle", _hintStr, getPosATL _box, 300] call FUNC(hintNear);
    [_this get "_taskId", "SUPP", "SUCCEEDED"] call A3A_fnc_taskSetState;

    // The elder takes the supplies in and leaves the pallet outside
    private _boxPos = getPosATL _box;
    deleteVehicle _box;
    private _pallet = "Land_Pallet_F" createVehicle _boxPos;
    [_pallet] call A3A_fnc_postmortem;

    _this set ["state", "s_cleanup"]; false;
}];

_task set ["s_elderDead", {
    private _city = _this get "_city";

    [SUPPORT_LOSS, _city] remoteExecCall ["A3A_fnc_citySupportChange", 2];

    private _hintStr = format [localize "STR_A3A_Tasks_SUP_Elderly_dead", [_city] call A3A_fnc_localizar];
    [_this get "_hintTitle", _hintStr, getPosATL (_this get "_house"), 500] call FUNC(hintNear);
    [_this get "_taskId", "SUPP", "FAILED"] call A3A_fnc_taskSetState;

    deleteVehicle (_this get "_box");
    _this set ["state", "s_cleanup"]; false;
}];

_task set ["s_boxLost", {
    [_this get "_hintTitle", localize "STR_A3A_Tasks_SUP_Elderly_lost", getPosATL (_this get "_house"), 500] call FUNC(hintNear);
    [_this get "_taskId", "SUPP", "FAILED"] call A3A_fnc_taskSetState;
    _this set ["state", "s_cleanup"]; false;
}];

_task set ["s_cleanup", {
    // The elder stays home until nobody is around
    [_this get "_elder"] call A3A_fnc_postmortem;
    [_this get "_taskId", "SUPP", 120] spawn A3A_fnc_taskDelete;
    true;       // delete the task
}];

_task;
