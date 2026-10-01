/*
Maintainer: Shoter
    Lost ammo supplies task. The enemy lost a large ammo crate while moving supplies. The crate's position
    is not revealed: 2-4 civilian witnesses are marked on the map with the bearing they saw it fall on,
    each off by up to 5 degrees, shown as arrows the players have to extend and cross to find it.
    20-40 minutes after the start the enemy sends a recovery team from their nearest outpost or airbase:
    an escort with troops and a cargo truck that loads the crate and drives it back to the outpost.
    Bringing the crate to HQ or a rebel outpost/airbase pays money and score, and the loot inside is kept.
    The task fails if the crate reaches the enemy outpost, or if nobody has it when the time runs out.

    Runs in the A3A_tasks_fnc_runTask framework: this file builds the task hashmap and its state functions.

Arguments:
    <ARRAY> Task params from FUNC(LOG_LostAmmo_p): [crate position ATL, source marker, [[witness position ATL, reported bearing], ...]]
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
_params params ["_cratePos", "_source", "_witnesses"];
Trace_1("Params: %1", _params);

private _side = sidesX getVariable _source;
if !(_side in [Occupants, Invaders]) then { _side = Occupants };
private _faction = Faction(_side);

private _task = createHashMap;
_task set ["_hintTitle", localize "STR_A3A_Tasks_LOG_LostAmmo_title"];
_task set ["_side", _side];
_task set ["_source", _source];
_task set ["_sourceName", [_source] call A3A_fnc_localizar];
_task set ["_factionName", _faction get "name"];
_task set ["_dispatchTime", time + 60 * (20 + random 20)];
_task set ["_endTime", time + 120*60];
_task set ["_dispatched", false];
_task set ["_recoveryActive", false];
_task set ["_found", false];
_task set ["_enemyHadCrate", false];
_task set ["_truck", objNull];

// The crate
private _crate = objNull;
isNil {
    _crate = createVehicle [_faction get "ammobox", _cratePos, [], 0, "CAN_COLLIDE"];
    _crate setDir random 360;
    _crate setVectorUp surfaceNormal _cratePos;
};
_crate allowDamage false;
[_crate] call A3A_Logistics_fnc_addLoadAction;
[_crate] spawn A3A_fnc_fillLootCrate;
_task set ["_crate", _crate];

private _taskId = "LOG" + str A3A_taskCount;
_task set ["_taskId", _taskId];

// Witnesses: a civilian looking along the reported bearing, and an arrow on the map pointing the same way
private _markers = [];
private _witnessUnits = [];
{
    _x params ["_pos", "_bearing"];
    private _group = createGroup [civilian, true];
    private _civ = [_group, FactionGet(civ, "unitMan"), _pos, [], 0, "NONE"] call A3A_fnc_createUnit;
    _civ setDir _bearing;
    _civ disableAI "PATH";
    _civ disableAI "FSM";
    _group setBehaviourStrong "SAFE";
    _civ doWatch (_pos getPos [300, _bearing]);
    _witnessUnits pushBack _civ;

    private _bearingText = str (round _bearing % 360);
    while { count _bearingText < 3 } do { _bearingText = "0" + _bearingText };
    private _mrkName = format ["A3A_lostAmmo_%1_%2", _taskId, _forEachIndex];

    // Local setters first, the last global one broadcasts the whole marker
    private _icon = createMarker [_mrkName + "_icon", _pos];
    _icon setMarkerShapeLocal "ICON";
    _icon setMarkerTypeLocal "mil_arrow";
    _icon setMarkerColorLocal "ColorOrange";
    _icon setMarkerDirLocal _bearing;
    _icon setMarkerText format [localize "STR_A3A_Tasks_LOG_LostAmmo_witness", _forEachIndex + 1, _bearingText];

    _markers pushBack _icon;
} forEach _witnesses;
_task set ["_markers", _markers];
_task set ["_witnessUnits", _witnessUnits];

// Task, pointed at the first witness so the crate position isn't given away
private _deadline = [((_task get "_endTime") - time) / 60] call FUNC(minutesFromNow);
_task set ["_deadline", _deadline];
private _taskDesc = format [localize "STR_A3A_Tasks_LOG_LostAmmo_desc", _task get "_factionName", count _witnesses, _task get "_sourceName", _deadline];
[[teamPlayer, civilian], _taskId, [_taskDesc, _task get "_hintTitle", ""], _witnesses#0#0, false, 0, true, "search", true] call BIS_fnc_taskCreate;
[_taskId, "LOG", "CREATED"] remoteExecCall ["A3A_fnc_taskUpdate", 2];

_task set ["state", "s_search"];
_task set ["interval", 2];

Trace_1("Initial data: %1", _task);


//////////////////////
// Helper functions //
//////////////////////

// Crate is at HQ or inside/near a rebel outpost or airbase
_task set ["_fnc_delivered", {
    params ["_pos"];
    if (_pos distance2d markerPos "Synd_HQ" < 100) exitWith {true};
    private _sites = (outposts + airportsX) select { sidesX getVariable _x == teamPlayer };
    _sites findIf { _pos inArea _x or _pos distance2d markerPos _x < 100 } != -1;
}];

_task set ["_fnc_rebelsNear", {
    params ["_pos", "_radius"];
    units teamPlayer inAreaArray [_pos, _radius, _radius] findIf { _x call A3A_fnc_canFight } != -1;
}];

_task set ["_fnc_hintAll", {
    params ["_task", "_text"];
    [_task get "_hintTitle", _text, [worldSize / 2, worldSize / 2], worldSize] call FUNC(hintNear);
}];

_task set ["_fnc_clearWaypoints", {
    params ["_group"];
    while { count waypoints _group > 0 } do { deleteWaypoint [_group, 0] };
}];

// Spawned on the server at dispatch time with the task as parameter.
// Escort vehicle with troops that secures the crate (and chases it if rebels drive off with it),
// plus a cargo truck that loads the crate once no rebels are around and drives it back to the source.
_task set ["_fnc_recovery", {
    params ["_task"];
    private _side = _task get "_side";
    private _source = _task get "_source";
    private _crate = _task get "_crate";
    private _faction = Faction(_side);
    private _fnc_clearWaypoints = _task get "_fnc_clearWaypoints";

    // Escort
    private _escort = objNull;
    private _cargoGroup = grpNull;
    private _escortGroups = [];
    private _pool = [_side, tierWar] call A3A_fnc_getVehiclesGroundTransport;
    if (_pool isNotEqualTo []) then {
        private _vehType = selectRandomWeighted _pool;
        private _data = [_vehType, "Normal", "legacy", [], _side, _source, getPosATL _crate] call A3A_fnc_createAttackVehicle;
        if (_data isEqualType objNull) exitWith { Debug_1("Escort vehicle spawn failed at %1", _source) };
        _data params ["_vehicle", "_crewGroup", "_cargo"];
        _escort = _vehicle;
        _cargoGroup = _cargo;
        _escortGroups = [_crewGroup, _cargo] select { !isNull _x };

        // Register as a support spend so the defence AI doesn't stack QRFs on top
        private _resources = (A3A_vehicleResourceCosts getOrDefault [_vehType, 0]) + 10 * count crew _vehicle;
        A3A_supportStrikes pushBack [_side, "TROOPS", getPosATL _crate, time + 3600, 3600, _resources];
        A3A_supportSpends pushBack [_side, getPosATL _crate, getPosATL _crate, _resources, time];
    };
    private _escortSoldiers = [];
    { _escortSoldiers append units _x } forEach _escortGroups;

    // Recovery truck, after the escort has cleared the vehicle spawn place
    sleep 10;
    private _truck = objNull;
    private _truckGroup = grpNull;
    private _truckTypes = _faction get "vehiclesCargo";
    if (_task get "_recoveryActive" and _truckTypes isNotEqualTo []) then {
        _truck = [_source, selectRandom _truckTypes, getPosATL _crate] call A3A_fnc_spawnVehicleAtMarker;
        if (isNull _truck) exitWith { Debug_1("Recovery truck spawn failed at %1", _source) };
        _truckGroup = [_side, _truck] call A3A_fnc_createVehicleCrew;
        _truckGroup deleteGroupWhenEmpty true;
        { [_x, nil, nil, "legacy"] call A3A_fnc_NATOinit } forEach units _truckGroup;
        [_truck, _side, "legacy"] call A3A_fnc_AIVEHinit;
        [getPosATL _truck, getPosATL _crate, _truckGroup] call A3A_fnc_WPCreate;
        _task set ["_truck", _truck];
    };

    private _truckTarget = getPosATL _crate;
    private _escortTarget = getPosATL _crate;
    private _escortDone = _escortGroups isEqualTo [];
    private _dismounted = isNull _cargoGroup;
    private _stoppedSince = -1;
    private _nextEscortUpdate = 0;

    while { _task get "_recoveryActive" and alive _crate } do {
        sleep 5;
        private _cratePos = getPosATL _crate;
        private _carrier = attachedTo _crate;

        // Truck: drive to the crate, load it when no rebels are around, then head home
        private _truckOk = alive _truck and { canMove _truck } and { alive driver _truck } and { side group driver _truck == _side };
        if (_truckOk and isNull _carrier) then {
            if (_cratePos distance2d _truckTarget > 50) then {
                _truckTarget = _cratePos;
                [_truckGroup] call _fnc_clearWaypoints;
                [getPosATL _truck, _truckTarget, _truckGroup] call A3A_fnc_WPCreate;
            };

            private _dist = _truck distance2d _crate;
            if (_dist > 150) exitWith { _stoppedSince = -1 };
            if (currentWaypoint _truckGroup >= count waypoints _truckGroup) then {
                private _wp = _truckGroup addWaypoint [_cratePos, 0];
                _wp setWaypointCompletionRadius 10;
                _truckGroup setCurrentWaypoint _wp;
            };

            // Close enough, or stuck nearby for a while: the crew winches it aboard
            if (vectorMagnitude velocity _truck > 1) then { _stoppedSince = -1 } else { if (_stoppedSince < 0) then { _stoppedSince = time } };
            if (_dist > 40 and { _stoppedSince < 0 or time - _stoppedSince < 45 }) exitWith {};
            if ([_cratePos, 75] call (_task get "_fnc_rebelsNear")) exitWith {};

            private _nodes = [_truck, _crate] call A3A_Logistics_fnc_canLoad;
            if (_nodes isEqualType 0) exitWith { Debug_1("Recovery truck can't load the crate, code %1", _nodes) };
            (_nodes + [true]) call A3A_Logistics_fnc_load;
            [_truckGroup] call _fnc_clearWaypoints;
            [getPosATL _truck, markerPos _source, _truckGroup] call A3A_fnc_WPCreate;
            _truckGroup setSpeedMode "FULL";
            _truckTarget = markerPos _source;
        };

        // Escort: follow the crate around until the truck has it or the escort is beaten
        if (_escortDone or time < _nextEscortUpdate) then { continue };
        _nextEscortUpdate = time + 20;
        if ({ _x call A3A_fnc_canFight } count _escortSoldiers < 0.33 * count _escortSoldiers
            or { !isNull _truck and { _carrier == _truck } }) then {
            _escortDone = true;
            { if (units _x isNotEqualTo []) then { [_x] spawn A3A_fnc_enemyReturnToBase } } forEach _escortGroups;
            continue;
        };

        // Passengers get out once the escort has reached a crate that isn't driving away
        if (!_dismounted and { _escort distance2d _cratePos < 200 } and { isNull _carrier or { vectorMagnitude velocity _carrier < 3 } }) then {
            _dismounted = true;
            { unassignVehicle _x } forEach units _cargoGroup;
            _cargoGroup leaveVehicle _escort;
        };

        // Rebels moved the crate: send everyone after it. Until then the attack vehicle waypoints stand.
        if (_cratePos distance2d _escortTarget < 100) then { continue };
        _escortTarget = _cratePos;
        {
            private _grp = _x;
            if (units _grp isEqualTo []) then { continue };
            if (!isNull _carrier) then { _grp reveal [_carrier, 1.5] };
            [_grp] call _fnc_clearWaypoints;
            private _wp = _grp addWaypoint [_cratePos, 0];
            private _mounted = vehicle leader _grp != leader _grp;
            _wp setWaypointType (["SAD", "MOVE"] select _mounted);
            _wp setWaypointBehaviour (["COMBAT", "AWARE"] select _mounted);
            _wp setWaypointSpeed "FULL";
            _wp setWaypointCompletionRadius 50;
            _grp setCurrentWaypoint _wp;
        } forEach _escortGroups;
    };

    // Task over: everyone goes home, vehicles despawn once nobody is around (the truck with the crate, if aboard)
    if (!_escortDone) then {
        { if (units _x isNotEqualTo []) then { [_x] spawn A3A_fnc_enemyReturnToBase } } forEach _escortGroups;
    };
    if (!isNull _escort) then { [_escort] spawn A3A_fnc_VEHdespawner };
    if (!isNull _truck) then {
        if (units _truckGroup isNotEqualTo []) then { [_truckGroup] spawn A3A_fnc_enemyReturnToBase };
        [_truck] spawn A3A_fnc_VEHdespawner;
    };
}];


/////////////////////
// State functions //
/////////////////////

_task set ["s_search", {
    private _crate = _this get "_crate";
    if (!alive _crate) exitWith {
        [_this, localize "STR_A3A_Tasks_LOG_LostAmmo_timeout"] call (_this get "_fnc_hintAll");
        _this set ["state", "s_failure"]; false;
    };

    private _cratePos = getPosATL _crate;
    private _truck = _this get "_truck";
    private _enemyHasCrate = !isNull _truck and { attachedTo _crate == _truck };
    private _source = _this get "_source";
    private _sourceName = _this get "_sourceName";
    private _factionName = _this get "_factionName";

    if (!_enemyHasCrate and { [_cratePos] call (_this get "_fnc_delivered") }) exitWith {
        _this set ["state", "s_success"]; false;
    };

    if (_enemyHasCrate and { _cratePos distance2d markerPos _source < 250 }) exitWith {
        [_this, format [localize "STR_A3A_Tasks_LOG_LostAmmo_lost", _sourceName]] call (_this get "_fnc_hintAll");
        _this set ["state", "s_failure"]; false;
    };

    // Out of time, and no rebel is anywhere near the crate
    if (time > _this get "_endTime" and { (call A3A_fnc_playableUnits) inAreaArray [_cratePos, 500, 500] isEqualTo [] }) exitWith {
        [_this, localize "STR_A3A_Tasks_LOG_LostAmmo_timeout"] call (_this get "_fnc_hintAll");
        _this set ["state", "s_failure"]; false;
    };

    // The recovery team sets off
    if (!(_this get "_dispatched") and { time > _this get "_dispatchTime" }) then {
        _this set ["_dispatched", true];
        _this set ["_recoveryActive", true];
        [_this] spawn (_this get "_fnc_recovery");
        [_this, format [localize "STR_A3A_Tasks_LOG_LostAmmo_dispatch", _factionName, _sourceName]] call (_this get "_fnc_hintAll");
    };

    private _taskId = _this get "_taskId";
    private _foundDesc = format [localize "STR_A3A_Tasks_LOG_LostAmmo_foundDesc", _this get "_deadline"];

    // First rebel player at the crate: it's no longer a secret
    if (!(_this get "_found") and { (call A3A_fnc_playableUnits) inAreaArray [_cratePos, 25, 25] isNotEqualTo [] }) then {
        _this set ["_found", true];
        [_this get "_hintTitle", localize "STR_A3A_Tasks_LOG_LostAmmo_found", _cratePos, 300] call FUNC(hintNear);
        [_taskId, [_foundDesc, _this get "_hintTitle", ""]] call BIS_fnc_taskSetDescription;
        [_taskId, [_crate, true]] call BIS_fnc_taskSetDestination;
    };

    // The enemy loaded the crate onto their truck, or the rebels took it back
    if (_enemyHasCrate isNotEqualTo (_this get "_enemyHadCrate")) then {
        _this set ["_enemyHadCrate", _enemyHasCrate];
        if (_enemyHasCrate) then {
                [_this get "_hintTitle", format [localize "STR_A3A_Tasks_LOG_LostAmmo_loaded", _sourceName], _cratePos, 2000] call FUNC(hintNear);
            private _desc = format [localize "STR_A3A_Tasks_LOG_LostAmmo_loadedDesc", _factionName, _sourceName, _this get "_deadline"];
            [_taskId, [_desc, _this get "_hintTitle", ""]] call BIS_fnc_taskSetDescription;
            [_taskId, markerPos _source] call BIS_fnc_taskSetDestination;
        } else {
            [_taskId, [_foundDesc, _this get "_hintTitle", ""]] call BIS_fnc_taskSetDescription;
            [_taskId, [_crate, true]] call BIS_fnc_taskSetDestination;
        };
    };

    false;
}];

_task set ["s_success", {
    private _crate = _this get "_crate";
    [0, 300] remoteExec ["A3A_fnc_resourcesFIA", 2];
    if (call A3A_fnc_playableUnits isNotEqualTo []) then {
        [30, true, _crate, 200] call FUNC(rewardPlayers);   // grouped players within 200m
    };

    [_this get "_hintTitle", localize "STR_A3A_Tasks_LOG_LostAmmo_success", getPosATL _crate, 500] call FUNC(hintNear);
    [_this get "_taskId", "LOG", "SUCCEEDED"] call A3A_fnc_taskSetState;
    _this set ["_successful", true];
    _this set ["state", "s_cleanup"]; false;
}];

_task set ["s_failure", {
    [_this get "_taskId", "LOG", "FAILED"] call A3A_fnc_taskSetState;
    _this set ["state", "s_cleanup"]; false;
}];

_task set ["s_cleanup", {
    _this set ["_recoveryActive", false];
    { deleteMarker _x } forEach (_this get "_markers");
    { [group _x] spawn A3A_fnc_groupDespawner } forEach ((_this get "_witnessUnits") select { !isNull _x });

    // A crate left lying around after a failure goes once no rebel is close. On the enemy truck it goes with the truck.
    private _crate = _this get "_crate";
    if (!(_this getOrDefault ["_successful", false]) and { alive _crate } and { isNull attachedTo _crate }) then {
        _crate spawn {
            waitUntil { sleep 30; !alive _this or { !([distanceSPWN, 1, _this, teamPlayer] call A3A_fnc_distanceUnits) } };
            deleteVehicle _this;
        };
    };

    [_this get "_taskId", "LOG", 1200] spawn A3A_fnc_taskDelete;
    true;       // delete the task
}];

_task;
