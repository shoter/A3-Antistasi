/*
Maintainer: Shoter
    Collaborator car ambush task. A police car waits in an enemy town with a police driver and a civilian
    collaborator next to him, plus two more policemen when the car has room (sometimes, always in the hard variant).
    After 5-15 minutes, or earlier if the police spot rebels or take fire, it drives to an outpost of the same side.
    Killing the collaborator before he gets there wins; if he arrives, the enemy learns more about the rebel HQ.

    On the way: if the car is hit it speeds off and ignores the fight, if the driver dies someone else in the car
    takes the wheel (the collaborator himself if nobody else is left), and if the car is disabled they carry on on foot.
    If the destination outpost falls, they head for the nearest outpost or airbase of their side instead.

    Runs in the A3A_tasks_fnc_runTask framework: this file builds the task hashmap and its state functions.

Arguments:
    <ARRAY> Task params from FUNC(AS_Collaborator_p): [town marker, car position ATL, car direction, destination outpost marker]
            plus the hard flag rolled by the mission board [DEFAULT = false]
    <ANY> Checkpoint data, unused (task is not saved)

Return Value:
    <HASHMAP> Task

Scope: Server
Environment: Scheduled
Public: No
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

params ["_params", "_checkpoint"];
_params params ["_city", "_placePos", "_placeDir", "_destMrk", ["_hard", false]];
Trace_1("Params: %1", _params);

private _side = sidesX getVariable _city;
if !(_side in [Occupants, Invaders]) then { _side = Occupants };
private _faction = Faction(_side);

private _task = createHashMap;
_task set ["_hintTitle", localize "STR_A3A_Tasks_AS_Collaborator_title"];
_task set ["_city", _city];
_task set ["_side", _side];
_task set ["_destMrk", _destMrk];
_task set ["_hard", _hard];
_task set ["_departTime", time + (5 + random 10) * 60];
_task set ["_fleeing", false];
_task set ["_onFoot", false];

// Police car
private _carType = selectRandom (_faction get "vehiclesPolice");
private _car = objNull;
isNil {
    _car = createVehicle [_carType, _placePos, [], 0, "CAN_COLLIDE"];
    _car setDir _placeDir;
};
[_car, _side] call A3A_fnc_AIVEHinit;
_task set ["_car", _car];

// Police driver and the collaborator next to him. The collaborator is in the police group, so killing him counts
// as killing an enemy rather than a civilian.
private _group = createGroup [_side, true];
private _driver = [_group, _faction get "unitPoliceGrunt", _placePos, [], 0, "NONE"] call A3A_fnc_createUnit;
_driver moveInDriver _car;
private _collaborator = [_group, FactionGet(civ, "unitMan"), _placePos, [], 0, "NONE"] call A3A_fnc_createUnit;
removeAllWeapons _collaborator;
_collaborator moveInCargo _car;
if (vehicle _collaborator == _collaborator) then { _collaborator moveInAny _car };
_collaborator setVariable ["A3A_collaborator", true, true];
_collaborator allowFleeing 0;

// Two more policemen when there is room: half the time, always in the hard variant
private _freeSeats = count (fullCrew [_car, "", true] select { isNull (_x # 0) });
if (_freeSeats >= 2 and (_hard or random 1 < 0.5)) then {
    for "_i" from 1 to 2 do {
        private _guard = [_group, _faction get "unitPoliceGrunt", _placePos, [], 0, "NONE"] call A3A_fnc_createUnit;
        _guard moveInAny _car;
    };
};
{ [_x, "", false, "legacy"] call A3A_fnc_NATOinit } forEach (units _group - [_collaborator]);
{
    _x addEventHandler ["Hit", {
        (_this # 0) setVariable ["A3A_unitHit", true];
        (_this # 0) removeEventHandler [_thisEvent, _thisEventHandler];
    }];
} forEach units _group;
_group addVehicle _car;
_group selectLeader _driver;
_group setBehaviourStrong "SAFE";
_group setSpeedMode "LIMITED";
_task set ["_group", _group];
_task set ["_collaborator", _collaborator];

// Task
private _cityName = [_city] call A3A_fnc_localizar;
_task set ["_cityName", _cityName];
private _taskId = "AS" + str A3A_taskCount;
private _displayTime = [((_task get "_departTime") - time) / 60] call FUNC(minutesFromNow);
private _taskDesc = format [localize "STR_A3A_Tasks_AS_Collaborator_desc", _cityName, _faction get "name", [_destMrk] call A3A_fnc_localizar, _displayTime];
[[teamPlayer, civilian], _taskId, [_taskDesc, _task get "_hintTitle", ""], [_collaborator, true], false, 0, true, "Kill", true] call BIS_fnc_taskCreate;
[_taskId, "AS", "CREATED"] remoteExecCall ["A3A_fnc_taskUpdate", 2];
_task set ["_taskId", _taskId];

_task set ["state", "s_waiting"];
_task set ["interval", 1];

Trace_1("Initial data: %1", _task);


//////////////////////
// Helper functions //
//////////////////////

// Route the group to the destination outpost
_task set ["_fnc_setRoute", {
    params ["_task"];
    private _group = _task get "_group";
    while { count waypoints _group > 0 } do { deleteWaypoint [_group, 0] };
    private _wp = _group addWaypoint [markerPos (_task get "_destMrk"), 30];
    _wp setWaypointType "MOVE";
    _group setCurrentWaypoint _wp;

    private _taskDesc = format [localize "STR_A3A_Tasks_AS_Collaborator_transitDesc", _task get "_cityName", [_task get "_destMrk"] call A3A_fnc_localizar];
    [_task get "_taskId", [_taskDesc, _task get "_hintTitle", ""]] call BIS_fnc_taskSetDescription;
}];

// Speed off and ignore the fight
_task set ["_fnc_flee", {
    params ["_task"];
    if (_task get "_fleeing") exitWith {};
    _task set ["_fleeing", true];
    private _group = _task get "_group";
    _group setBehaviourStrong "CARELESS";
    _group setSpeedMode "FULL";
}];

// True if any member of the group took a hit
_task set ["_fnc_wasHit", {
    units (_this get "_group") findIf { _x getVariable ["A3A_unitHit", false] } != -1;
}];


/////////////////////
// State functions //
/////////////////////

_task set ["s_waiting", {
    private _collaborator = _this get "_collaborator";
    if (!alive _collaborator) exitWith { _this set ["state", "s_success"]; false };

    // Leave early when shot at or when rebels (not undercover) are spotted nearby
    private _group = _this get "_group";
    private _spotted = units teamPlayer inAreaArray [getPosATL _collaborator, 300, 300]
        findIf { alive _x and !captive _x and { _group knowsAbout _x > 1.4 } } != -1;
    private _early = _spotted or { _this call (_this get "_fnc_wasHit") };
    if (_early) then {
        [_this get "_hintTitle", localize "STR_A3A_Tasks_AS_Collaborator_early", getPosATL _collaborator, 1000] call FUNC(hintNear);
        [_this] call (_this get "_fnc_flee");
    };

    if (_early or time > _this get "_departTime") exitWith {
        [_this] call (_this get "_fnc_setRoute");
        _this set ["_arriveBy", time + 45*60];
        _this set ["state", "s_transit"]; false;
    };
    false;
}];

_task set ["s_transit", {
    private _collaborator = _this get "_collaborator";
    if (!alive _collaborator) exitWith { _this set ["state", "s_success"]; false };

    private _side = _this get "_side";
    private _group = _this get "_group";
    private _car = _this get "_car";
    private _pos = getPosATL _collaborator;

    // Destination fell: head for the nearest outpost or airbase of the same side
    private _destMrk = _this get "_destMrk";
    if (sidesX getVariable _destMrk != _side) then {
        private _alternatives = (outposts + airportsX) select { sidesX getVariable _x == _side };
        if (_alternatives isEqualTo []) exitWith {};
        private _distances = _alternatives apply { markerPos _x distance2d _pos };
        _destMrk = _alternatives # (_distances find selectMin _distances);
        _this set ["_destMrk", _destMrk];
        [_this] call (_this get "_fnc_setRoute");
        private _hintStr = format [localize "STR_A3A_Tasks_AS_Collaborator_redirect", [_destMrk] call A3A_fnc_localizar];
        [_this get "_hintTitle", _hintStr, _pos, 1000] call FUNC(hintNear);
    };

    if (_pos distance2d markerPos _destMrk < 100 or { _pos inArea _destMrk }) exitWith {
        _this set ["_arrived", true];
        _this set ["state", "s_failure"]; false;
    };
    if (time > _this get "_arriveBy") exitWith { _this set ["state", "s_failure"]; false };

    if (_this call (_this get "_fnc_wasHit")) then { [_this] call (_this get "_fnc_flee") };

    if !(_this get "_onFoot") then {
        // Driver down: someone else in the car takes the wheel, the collaborator himself if nobody else is left.
        // Changing seats takes a moment, so wait before checking again, and give up after three tries.
        private _driverless = !alive driver _car;
        private _swapping = time < (_this getOrDefault ["_swapUntil", 0]);
        if (canMove _car and _driverless and !_swapping and (_this getOrDefault ["_swaps", 0]) < 3) then {
            private _inCar = crew _car select { alive _x };
            private _police = _inCar - [_collaborator];
            private _newDriver = if (_police isNotEqualTo []) then { _police # 0 } else { [objNull, _collaborator] select (_collaborator in _inCar) };
            if (!isNull _newDriver) then {
                if (!isNull driver _car) then { moveOut (driver _car) };
                _newDriver action ["MoveToDriver", _car];
                _group selectLeader _newDriver;
                _this set ["_swapUntil", time + 10];
                _this set ["_swaps", (_this getOrDefault ["_swaps", 0]) + 1];
                _swapping = true;
            };
        };
        // Car disabled, or nobody took the wheel: carry on on foot
        if (!canMove _car or { _driverless and !_swapping }) then {
            _this set ["_onFoot", true];
            _group leaveVehicle _car;
        };
    };
    false;
}];

_task set ["s_success", {
    private _collaborator = _this get "_collaborator";
    private _bonus = [1, 2] select (_this get "_hard");

    [_this get "_hintTitle", localize "STR_A3A_Tasks_AS_Collaborator_dead", getPosATL _collaborator, 1000] call FUNC(hintNear);
    [0, 300 * _bonus] remoteExec ["A3A_fnc_resourcesFIA", 2];
    [30 * _bonus, false, getPosATL _collaborator, 500] call FUNC(rewardPlayers);     // any players within 500m
    [_this get "_side", 5, 60] remoteExec ["A3A_fnc_addAggression", 2];
    [_this get "_taskId", "AS", "SUCCEEDED"] call A3A_fnc_taskSetState;

    [_this get "_group"] spawn A3A_fnc_enemyReturnToBase;
    _this set ["state", "s_cleanup"]; false;
}];

_task set ["s_failure", {
    private _collaborator = _this get "_collaborator";
    [-10, theBoss] call A3A_fnc_playerScoreAdd;

    // He talks: the enemy learns more about where the rebel HQ is
    if (_this getOrDefault ["_arrived", false]) then {
        [_this get "_hintTitle", localize "STR_A3A_Tasks_AS_Collaborator_arrived", getPosATL _collaborator, 1000] call FUNC(hintNear);
        if (_this get "_side" == Invaders) then {
            A3A_curHQInfoInv = A3A_curHQInfoInv + 0.1 + random 0.2;
        } else {
            A3A_curHQInfoOcc = A3A_curHQInfoOcc + 0.1 + random 0.2;
        };
    };
    [_this get "_taskId", "AS", "FAILED"] call A3A_fnc_taskSetState;

    [_this get "_group"] spawn A3A_fnc_groupDespawner;
    _this set ["state", "s_cleanup"]; false;
}];

_task set ["s_cleanup", {
    [_this get "_car"] spawn A3A_fnc_VEHdespawner;
    [_this get "_taskId", "AS", 1200] spawn A3A_fnc_taskDelete;
    true;       // delete the task
}];

_task;
