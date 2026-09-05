/*
Maintainer: Shoter
    Defector escort task. An enemy officer waits in a civilian car near one of their outposts.
    Once picked up, their own side calls support on the escort and sends a road patrol after it.
    Delivering the officer alive to HQ or a rebel airbase (or, in the boat variant, to a rebel seaport)
    pays a large intel roll, money and a temporary aggression drop. If the officer dies, the task fails.

    Runs in the A3A_tasks_fnc_runTask framework: this file builds the task hashmap and its state functions.

Arguments:
    <ARRAY> Task params from FUNC(RES_Defector_p): [source marker, pickup position ATL, car direction, variant, destination marker]
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
_params params ["_source", "_placePos", "_placeDir", "_variant", "_destMrk"];
Trace_1("Params: %1", _params);

private _side = sidesX getVariable _source;
if !(_side in [Occupants, Invaders]) then { _side = Occupants };
private _faction = Faction(_side);

private _task = createHashMap;
_task set ["_hintTitle", localize "STR_A3A_Tasks_RES_Defector_title"];
_task set ["_source", _source];
_task set ["_side", _side];
_task set ["_variant", _variant];
_task set ["_destMrk", _destMrk];
_task set ["_endTime", time + 45*60];
_task set ["_chaseActive", false];

// The car the officer waits in
private _carTypes = arrayCivVeh select {
    _x isKindOf "Car_F" and !(_x isKindOf "Truck_F")
    and getNumber (configFile >> "CfgVehicles" >> _x >> "transportSoldier") >= 2
};
private _carType = if (_carTypes isEqualTo []) then { "C_Offroad_01_F" } else { selectRandom _carTypes };
private _car = objNull;
isNil {
    _car = createVehicle [_carType, _placePos, [], 0, "CAN_COLLIDE"];
    _car setDir _placeDir;
};
[_car, civilian] call A3A_fnc_AIVEHinit;
_task set ["_car", _car];

// The officer. Rebel side so that their former friends shoot at them, captive until picked up so they don't get shot in the car.
private _officerType = _faction get "unitOfficial";
private _identity = [_faction, _officerType] call A3A_fnc_createRandomIdentity;
private _group = createGroup [teamPlayer, true];
private _officer = [_group, _officerType, _placePos, [], 0, "NONE", _identity] call A3A_fnc_createUnit;
removeAllWeapons _officer;
removeBackpackGlobal _officer;
_officer setCaptive true;
_officer disableAI "PATH";
_officer disableAI "FSM";           // same set as the taxi task: prevents the passenger jumping out and running off
_officer disableAI "AUTOCOMBAT";
_officer disableAI "AUTOTARGET";
_officer disableAI "TARGET";
_officer allowFleeing 0;
_officer setUnitPos "UP";
_group setBehaviourStrong "CARELESS";
_officer setVariable ["A3A_defector", true, true];
_officer moveInCargo _car;
if (vehicle _officer == _officer) then { _officer moveInAny _car };
_task set ["_officer", _officer];

// Global follow action, same mechanism as the taxi task
private _addActionCode = {
    params ["_unit"];
    private _condition = toString { (isPlayer _this) and (alive _target) and (_target getVariable ["A3A_taxiDriver", objNull] != _this) };
    _unit addAction [localize "STR_A3A_Tasks_RES_Defector_follow", {
        params ["_target", "_caller"];
        _target setVariable ["A3A_taxiDriver", _caller, true];
        [_target, _caller] remoteExec ["A3A_fnc_AIfollow", _target];
    }, nil, 0, false, true, "", _condition, 4];
};
[_officer, _addActionCode] remoteExec ["call", 0, _officer];

// Task
private _destText = if (_variant == "boat") then {
    format [localize "STR_A3A_Tasks_RES_Defector_destBoat", [_destMrk] call A3A_fnc_localizar];
} else {
    localize "STR_A3A_Tasks_RES_Defector_destHQ";
};
_task set ["_destText", _destText];

private _taskId = "RES" + str A3A_taskCount;
private _displayTime = [((_task get "_endTime") - time) / 60] call FUNC(minutesFromNow);
private _taskDesc = format [localize "STR_A3A_Tasks_RES_Defector_desc", _faction get "name", [_source] call A3A_fnc_localizar, _displayTime, _destText];
[[teamPlayer, civilian], _taskId, [_taskDesc, _task get "_hintTitle", ""], _placePos, false, 0, true, "Meet", true] call BIS_fnc_taskCreate;
[_taskId, "RES", "CREATED"] remoteExecCall ["A3A_fnc_taskUpdate", 2];
_task set ["_taskId", _taskId];

_task set ["state", "s_waitForPickup"];
_task set ["interval", 1];

Trace_1("Initial data: %1", _task);


//////////////////////
// Helper functions //
//////////////////////

// Run where the officer is local: stop following, leave the vehicle and walk to a position
_task set ["_fnc_getOut", {
    params ["_officer", "_destPos"];
    private _handle = _officer getVariable "A3A_AIScriptHandle";
    if (!isNil "_handle") then { terminate _handle };
    _officer setVariable ["A3A_taxiDriver", objNull, true];
    unassignVehicle _officer;
    moveOut _officer;
    _officer enableAI "PATH";
    _officer doMove _destPos;
}];

// Spawned on the server with the task as parameter. Enemy road patrol from the source outpost, vectored on the officer.
_task set ["_fnc_chase", {
    params ["_task"];
    private _side = _task get "_side";
    private _source = _task get "_source";
    private _officer = _task get "_officer";

    private _pool = [_side, tierWar] call A3A_fnc_getVehiclesGroundTransport;
    if (_pool isEqualTo []) exitWith {};
    private _vehType = selectRandomWeighted _pool;
    private _data = [_vehType, "Normal", "legacy", [], _side, _source, getPosATL _officer] call A3A_fnc_createAttackVehicle;
    if (_data isEqualType objNull) exitWith { Debug_1("Chase vehicle spawn failed at %1", _source) };
    _data params ["_vehicle", "_crewGroup", "_cargoGroup"];
    _task set ["_chaseVehicle", _vehicle];

    // Register as a support spend so the defence AI doesn't stack QRFs on top
    private _resources = (A3A_vehicleResourceCosts getOrDefault [_vehType, 0]) + 10 * count crew _vehicle;
    A3A_supportStrikes pushBack [_side, "TROOPS", getPosATL _officer, time + 1800, 1800, _resources];
    A3A_supportSpends pushBack [_side, getPosATL _officer, getPosATL _officer, _resources, time];

    private _groups = [_crewGroup, _cargoGroup] select { !isNull _x };
    private _soldiers = [];
    { _soldiers append units _x } forEach _groups;
    private _endTime = time + 30*60;
    private _dismounted = false;

    while { _task get "_chaseActive" and alive _officer and time < _endTime } do {
        if ({ _x call A3A_fnc_canFight } count _soldiers < 0.5 * count _soldiers) exitWith {};
        if (!_dismounted and !canMove _vehicle) exitWith {};

        private _targetVeh = vehicle _officer;
        private _targetPos = getPosATL _officer;

        // Dismount the passengers once the patrol has caught up with a stopped or unmounted escort
        if (!_dismounted and !isNull _cargoGroup and _vehicle distance2d _targetPos < 150
            and (_targetVeh == _officer or vectorMagnitude velocity _targetVeh < 3)) then {
            _dismounted = true;
            { unassignVehicle _x } forEach units _cargoGroup;
            _cargoGroup leaveVehicle _vehicle;
        };

        {
            private _grp = _x;
            _grp reveal [_targetVeh, 1.5];
            while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0] };
            private _wp = _grp addWaypoint [_targetPos, 0];
            private _mounted = vehicle leader _grp != leader _grp;
            _wp setWaypointType (["SAD", "MOVE"] select _mounted);
            _wp setWaypointBehaviour (["COMBAT", "AWARE"] select _mounted);
            _wp setWaypointSpeed "FULL";
            _wp setWaypointCompletionRadius 50;
            _grp setCurrentWaypoint _wp;
        } forEach (_groups select { units _x isNotEqualTo [] });

        sleep 20;
    };

    { if (!isNull _x) then { [_x] spawn A3A_fnc_enemyReturnToBase } } forEach _groups;
    [_vehicle] spawn A3A_fnc_VEHdespawner;
}];

// Spawned on the server on success in the boat variant: a civilian boat picks the officer up at the seaport
_task set ["_fnc_boatExtract", {
    params ["_officer", "_destMrk"];
    private _portPos = markerPos _destMrk;
    private _boatPos = [_portPos, 15, 200, 5, 2, 0.5, 0, [], [[0,0,0],[0,0,0]]] call BIS_fnc_findSafePos;
    if (_boatPos distance2d _portPos > 300) exitWith { deleteVehicle _officer };     // no water nearby, the officer just leaves

    private _boatType = selectRandom (FactionGet(reb, "vehiclesCivBoat"));
    private _boat = createVehicle [_boatType, _boatPos, [], 0, "NONE"];
    _boat allowDamage false;
    _boat setDir (_boatPos getDir _portPos);
    private _crewGroup = createGroup [civilian, true];
    private _skipper = [_crewGroup, FactionGet(civ, "unitMan"), _boatPos, [], 0, "NONE"] call A3A_fnc_createUnit;
    _skipper allowDamage false;
    _skipper moveInDriver _boat;
    _crewGroup setBehaviourStrong "CARELESS";

    private _shorePos = getPosATL _boat;
    _officer doMove _shorePos;
    private _timeout = time + 60;
    waitUntil { sleep 2; !alive _officer or _officer distance2d _boat < 12 or time > _timeout };
    if (alive _officer) then { _officer moveInCargo _boat; if (vehicle _officer == _officer) then { _officer moveInAny _boat } };

    private _seaPos = _boatPos getPos [800, _portPos getDir _boatPos];
    _crewGroup addWaypoint [_seaPos, 0];
    sleep 120;
    deleteVehicle _officer;
    deleteVehicle _skipper;
    deleteVehicle _boat;
    deleteGroup _crewGroup;
}];


/////////////////////
// State functions //
/////////////////////

_task set ["s_waitForPickup", {
    private _officer = _this get "_officer";

    if (!alive _officer) exitWith {
        [_this get "_hintTitle", localize "STR_A3A_Tasks_RES_Defector_dead", getPosATL _officer, 500] call FUNC(hintNear);
        _this set ["state", "s_failure"]; false;
    };

    if (time > _this get "_endTime") exitWith {
        [_this get "_hintTitle", localize "STR_A3A_Tasks_RES_Defector_timeout", getPosATL _officer, 500] call FUNC(hintNear);
        _this set ["state", "s_failure"]; false;
    };

    // Picked up either through the follow action or by a player driving off with the officer's car
    private _driver = driver vehicle _officer;
    if (vehicle _officer != _officer and isPlayer _driver and side group _driver == teamPlayer) then {
        _officer setVariable ["A3A_taxiDriver", _driver, true];
    };
    if (isNull (_officer getVariable ["A3A_taxiDriver", objNull])) exitWith {false};

    // Officer is now fair game for their own side
    _officer setCaptive false;
    [_officer, false] remoteExec ["setCaptive", _officer];

    _this set ["_endTime", time + 45*60];
    private _displayTime = [((_this get "_endTime") - time) / 60] call FUNC(minutesFromNow);
    private _taskDesc = format [localize "STR_A3A_Tasks_RES_Defector_transitDesc", _this get "_destText", _displayTime];
    [_this get "_taskId", [_taskDesc, _this get "_hintTitle", ""]] call BIS_fnc_taskSetDescription;
    [_this get "_taskId", markerPos (_this get "_destMrk")] call BIS_fnc_taskSetDestination;

    private _hintStr = format [localize "STR_A3A_Tasks_RES_Defector_pickup", _this get "_destText"];
    [_this get "_hintTitle", _hintStr, getPosATL _officer, 100] call FUNC(hintNear);

    // The enemy notices the officer is gone: support call on the escort and a road patrol from the outpost
    private _side = _this get "_side";
    private _source = _this get "_source";
    [_side, _officer, markerPos _source, 3] remoteExec ["A3A_fnc_requestSupport", 2];
    _this set ["_chaseActive", true];
    [_this] spawn (_this get "_fnc_chase");

    _this set ["state", "s_transit"]; false;
}];

_task set ["s_transit", {
    private _officer = _this get "_officer";
    if (!alive _officer) exitWith {
        [_this get "_hintTitle", localize "STR_A3A_Tasks_RES_Defector_dead", getPosATL _officer, 500] call FUNC(hintNear);
        [_this get "_taskId", "FAILED", getPosATL _officer, 500] call FUNC(taskNotifyNear);
        _this set ["state", "s_failure"]; false;
    };

    private _pos = getPosATL _officer;
    private _vehSpeed = vectorMagnitude velocity vehicle _officer;

    // Delivery: within 100m of HQ or inside a rebel airbase, or at the seaport in the boat variant
    private _delivered = call {
        if (_vehSpeed >= 2) exitWith {false};
        if (_this get "_variant" == "boat") exitWith {
            private _destMrk = _this get "_destMrk";
            _pos inArea _destMrk or _pos distance2d markerPos _destMrk < 100;
        };
        if (_pos distance2d markerPos respawnTeamPlayer < 100) exitWith {true};
        if (_pos distance2d markerPos "Synd_HQ" < 100) exitWith {true};
        private _rebelAirports = airportsX select { sidesX getVariable _x == teamPlayer };
        _rebelAirports findIf { _pos inArea _x or _pos distance2d markerPos _x < 100 } != -1;
    };
    if (_delivered) exitWith {
        private _destPos = if (_this get "_variant" == "boat") then { markerPos (_this get "_destMrk") } else { getPosATL petros };
        [[_officer, _destPos], _this get "_fnc_getOut"] remoteExec ["call", _officer];
        _this set ["state", "s_success"]; false;
    };

    // Out of time and not moving: the officer gives up on us
    if (time > _this get "_endTime" and _vehSpeed < 2) exitWith {
        [_this get "_hintTitle", localize "STR_A3A_Tasks_RES_Defector_angry", _pos, 100] call FUNC(hintNear);
        private _destPos = _pos getPos [1000, random 360];
        [[_officer, _destPos], _this get "_fnc_getOut"] remoteExec ["call", _officer];
        [_this get "_taskId", "FAILED", _pos, 500] call FUNC(taskNotifyNear);
        _this set ["state", "s_failure"]; false;
    };
    false;
}];

_task set ["s_success", {
    private _officer = _this get "_officer";
    private _side = _this get "_side";
    private _money = 2000 + 100 * floor random 41;          // 2000-6000

    [0, _money] remoteExec ["A3A_fnc_resourcesFIA", 2];
    [_side, -15, 90] remoteExec ["A3A_fnc_addAggression", 2];
    [30, true, _officer, 300] call FUNC(rewardPlayers);     // grouped players within 300m
    ["Large", _side] call A3A_fnc_selectIntel;

    private _hintStr = format [localize "STR_A3A_Tasks_RES_Defector_success", _money, Faction(_side) get "name"];
    [_this get "_hintTitle", _hintStr, getPosATL _officer, 500] call FUNC(hintNear);
    [_this get "_taskId", "SUCCEEDED", getPosATL _officer, 500] call FUNC(taskNotifyNear);
    [_this get "_taskId", "RES", "SUCCEEDED"] call A3A_fnc_taskSetState;

    if (_this get "_variant" == "boat") then {
        [_this get "_hintTitle", localize "STR_A3A_Tasks_RES_Defector_boat", getPosATL _officer, 300] call FUNC(hintNear);
        [_officer, _this get "_destMrk"] spawn (_this get "_fnc_boatExtract");
    } else {
        _officer spawn { sleep 120; deleteVehicle _this };
    };

    _this set ["state", "s_cleanup"]; false;
}];

_task set ["s_failure", {
    [-10, theBoss] call A3A_fnc_playerScoreAdd;
    [_this get "_taskId", "RES", "FAILED"] call A3A_fnc_taskSetState;
    (_this get "_officer") spawn { sleep 60; deleteVehicle _this };
    _this set ["state", "s_cleanup"]; false;
}];

_task set ["s_cleanup", {
    _this set ["_chaseActive", false];
    [_this get "_car"] spawn A3A_fnc_VEHdespawner;
    [_this get "_taskId", "RES", 1200] spawn A3A_fnc_taskDelete;
    true;       // delete the task
}];

_task;
