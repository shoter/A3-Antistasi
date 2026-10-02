/*
Maintainer: Shoter
    Enemy mortar fire event. Not posted on the mission board: A3A_tasks_fnc_eventLoop starts it at random.
    The enemy gets a mortar team ready at one of its outposts or airbases to shell a rebel place 1-2 km away.
    The briefing gives a 5-30 minute window. When the hidden start time comes, with no message,
    a truck brings an infantry squad to the firing area, where it patrols 200 m around the spot, and the mortar
    team walks there from the base. On arrival the team sets up the mortar and fires 20 rounds, 4 a minute, on
    the rebel place.
    Where the place is spawned the rounds do the damage themselves. Where it is not, each round can kill a
    garrison soldier or (in towns) a civilian on paper. Every civilian the barrage kills costs a lot of town support,
    and rounds can bring down houses near where they land.
    Killing the mortar team (or destroying the mortar) succeeds: faction money and reward points, plus town
    support if it never fired. After the full barrage the task fails and everyone walks back to base.

    Runs in the A3A_tasks_fnc_runTask framework: this file builds the task hashmap and its state functions.

Arguments:
    <ARRAY> Task params from FUNC(EVT_Mortar_p): [target marker, enemy base marker, mortar position ATL, enemy side]
    <ANY> Checkpoint data, unused (task is not saved)

Return Value:
    <HASHMAP> Task

Scope: Server
Environment: Scheduled
Public: No
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

#define START_MIN 5
#define START_MAX 30
#define GIVE_UP_TIME 3600
#define AREA_RADIUS 250
#define AREA_OFFSET 70
#define PATROL_RADIUS 200
#define SETUP_TIME 40
#define ROUNDS 20
#define ROUND_INTERVAL 15
#define BUILDING_CHANCE 0.2
#define TROOP_CHANCE 0.2
#define CIV_CHANCE 0.3
#define CIV_DEATH_SUPPORT -5
#define SUCCESS_SUPPORT 10
#define REWARD_POINTS 20
#define PARTICIPANT_RADIUS 1000

params ["_params", "_checkpoint"];
_params params ["_target", "_base", "_mortarPos", "_side"];
Trace_1("Params: %1", _params);

private _faction = Faction(_side);
private _targetSize = markerSize _target;
private _spread = (((_targetSize # 0) max (_targetSize # 1)) * 0.5) max 50 min 150;

private _task = createHashMap;
_task set ["_hintTitle", localize "STR_A3A_Tasks_EVT_Mortar_title"];
_task set ["_target", _target];
_task set ["_targetName", [_target] call A3A_fnc_localizar];
_task set ["_base", _base];
_task set ["_mortarPos", _mortarPos];
_task set ["_side", _side];
_task set ["_spread", _spread];
_task set ["_startTime", time + 60 * (START_MIN + random (START_MAX - START_MIN))];
_task set ["_giveUpTime", 0];
_task set ["_reward", 200 + 50 * tierWar];
_task set ["_teamUnits", []];
_task set ["_team", grpNull];
_task set ["_truck", objNull];
_task set ["_crewGroup", grpNull];
_task set ["_escortGroup", grpNull];
_task set ["_escortState", "none"];
_task set ["_dropPos", _mortarPos];
_task set ["_truckLastPos", []];
_task set ["_truckStuckTime", 0];
_task set ["_mortar", objNull];
_task set ["_setupTime", 0];
_task set ["_pendingShot", []];              // [aim position, order time, rounds fired before the order]
_task set ["_nextShot", 0];
_task set ["_lastShotTime", 0];
_task set ["_flightTime", 30];
_task set ["_killedEH", -1];
_task set ["_civDeaths", 0];

// The map shows roughly where the mortar will be set up, and what it will shell
private _taskId = "MORTAR" + str A3A_taskCount;
private _areaPos = _mortarPos getPos [random AREA_OFFSET, random 360];
private _areaMrk = createMarker ["A3A_mortarArea_" + _taskId, _areaPos];
_areaMrk setMarkerShape "ELLIPSE";
_areaMrk setMarkerSize [AREA_RADIUS, AREA_RADIUS];
_areaMrk setMarkerBrush "FDiagonal";
_areaMrk setMarkerColor "ColorRed";
_areaMrk setMarkerAlpha 0.7;
_task set ["_areaMrk", _areaMrk];

private _targetMrk = createMarker ["A3A_mortarTarget_" + _taskId, markerPos _target];
_targetMrk setMarkerType "mil_warning";
_targetMrk setMarkerColor "ColorRed";
_targetMrk setMarkerText localize "STR_A3A_Tasks_EVT_Mortar_targetMarker";
_task set ["_targetMrk", _targetMrk];

private _fromTime = [START_MIN] call FUNC(minutesFromNow);
private _toTime = [START_MAX] call FUNC(minutesFromNow);
private _taskDesc = format [localize "STR_A3A_Tasks_EVT_Mortar_desc", _faction get "name", [_base] call A3A_fnc_localizar, _fromTime, _toTime, _task get "_targetName", _task get "_reward"];
[[teamPlayer, civilian], _taskId, [_taskDesc, _task get "_hintTitle", _areaMrk], _areaPos, false, 0, true, "Destroy", true] call BIS_fnc_taskCreate;
[_taskId, "MORTAR", "CREATED"] remoteExecCall ["A3A_fnc_taskUpdate", 2];
_task set ["_taskId", _taskId];

_task set ["state", "s_waitStart"];
_task set ["interval", 10];

Info_3("Mortar fire event on %1 from %2 at %3", _target, _base, _mortarPos);


//////////////////////
// Helper functions //
//////////////////////

// Called with the task. Sends the mortar team on foot and the escort squad by truck
_task set ["_fnc_spawnForces", {
    private _side = _this get "_side";
    private _faction = Faction(_side);
    private _basePos = markerPos (_this get "_base");
    private _mortarPos = _this get "_mortarPos";

    // Mortar team: two crewmen and a rifleman, on foot from the edge of the base facing the firing spot
    private _teamPos = [_basePos getPos [50, _basePos getDir _mortarPos], 0, 60, 3] call A3A_fnc_findPatrolPos;
    private _team = createGroup [_side, true];
    {
        private _unitType = _faction getOrDefault [_x, _faction get "unitRifle"];
        private _unit = [_team, _unitType, _teamPos, [], 3, "NONE"] call A3A_fnc_createUnit;
        [_unit, "", false, "legacy"] call A3A_fnc_NATOinit;
    } forEach ["unitStaticCrew", "unitStaticCrew", "unitRifle"];
    _team setBehaviourStrong "AWARE";
    _team setSpeedMode "NORMAL";
    _team setFormation "FILE";
    private _wp = _team addWaypoint [_mortarPos, 0];
    _wp setWaypointCompletionRadius 15;
    _this set ["_team", _team];
    _this set ["_teamUnits", units _team];

    // Escort squad, by truck as far as the roads go
    private _truckTypes = _faction get "vehiclesTrucks";
    if (_truckTypes isEqualTo []) then { _truckTypes = _faction get "vehiclesMilitiaTrucks" };
    private _truck = objNull;
    if (_truckTypes isNotEqualTo []) then {
        private _truckType = selectRandom _truckTypes;
        _truck = [_this get "_base", _truckType, _mortarPos] call A3A_fnc_spawnVehicleAtMarker;
        if (isNull _truck) then { _truck = [_truckType, _teamPos, 50, 5, true] call A3A_fnc_safeVehicleSpawn };
    };

    private _escort = grpNull;
    if (!isNull _truck) then {
        ([_truck, "Normal", "legacy", _side] call A3A_fnc_fillVehicleCrewCargo) params ["_crewGroup", "_cargoGroup"];
        _this set ["_truck", _truck];
        _this set ["_crewGroup", _crewGroup];
        _escort = _cargoGroup;

        private _roads = _mortarPos nearRoads 300;
        private _dropPos = if (_roads isEqualTo []) then { _mortarPos } else {
            getPosATL ([_roads, _mortarPos] call BIS_fnc_nearestPosition);
        };
        _this set ["_dropPos", _dropPos];
        private _truckWp = _crewGroup addWaypoint [_dropPos, 0];
        _truckWp setWaypointCompletionRadius 20;
        _crewGroup setBehaviourStrong "SAFE";
        _crewGroup setSpeedMode "NORMAL";
        _this set ["_truckLastPos", getPosATL _truck];
        _this set ["_truckStuckTime", time + 90];
    };

    if (isNull _escort) then {
        // No truck or no seats in it: the squad walks with the mortar team
        _escort = [_teamPos, _side, selectRandom (_faction get "groupsSquads")] call A3A_fnc_spawnGroup;
        { [_x, "", false, "legacy"] call A3A_fnc_NATOinit } forEach units _escort;
        private _escortWp = _escort addWaypoint [_mortarPos, 0];
        _escortWp setWaypointCompletionRadius 50;
        _this set ["_escortState", "walking"];
    } else {
        _this set ["_escortState", "driving"];
    };
    _this set ["_escortGroup", _escort];

    private _teamCount = count units _team;
    private _escortCount = count units _escort;
    Debug_3("Mortar event: team of %1 and escort of %2 left for %3", _teamCount, _escortCount, _mortarPos);
}];

// Called with the task every tick once the forces are out: escort drives, gets out, walks, patrols
_task set ["_fnc_escort", {
    private _escort = _this get "_escortGroup";
    if (isNull _escort) exitWith {};
    private _mortarPos = _this get "_mortarPos";

    switch (_this get "_escortState") do {
        case "driving": {
            private _truck = _this get "_truck";
            private _arrived = _truck distance2d (_this get "_dropPos") < 40;

            // Stuck, wrecked or without a driver: get out where it is
            private _stuck = false;
            if (time > _this get "_truckStuckTime") then {
                _stuck = _truck distance2d (_this get "_truckLastPos") < 10;
                _this set ["_truckLastPos", getPosATL _truck];
                _this set ["_truckStuckTime", time + 90];
            };
            if (!_arrived and !_stuck and { alive _truck and canMove _truck and { driver _truck call A3A_fnc_canFight } }) exitWith {};

            _escort leaveVehicle _truck;
            { unassignVehicle _x } forEach units _escort;
            private _wp = _escort addWaypoint [_mortarPos, 0];
            _wp setWaypointCompletionRadius 50;
            _escort setCurrentWaypoint _wp;
            _this set ["_escortState", "walking"];
        };
        case "walking": {
            if (leader _escort distance2d _mortarPos > PATROL_RADIUS) exitWith {};
            _escort setBehaviourStrong "AWARE";
            _escort setSpeedMode "LIMITED";
            _this set ["_escortState", "patrolling"];
        };
        case "patrolling": {
            if (currentWaypoint _escort < count waypoints _escort) exitWith {};
            private _wp = _escort addWaypoint [_mortarPos getPos [random PATROL_RADIUS, random 360], 0];
            _wp setWaypointCompletionRadius 15;
        };
    };
}];

// Called with the task. True when nobody of the mortar team can fight any more, or the mortar is gone
_task set ["_fnc_mortarStopped", {
    if ((_this get "_teamUnits") findIf { _x call A3A_fnc_canFight } == -1) exitWith {true};
    private _mortar = _this get "_mortar";
    (_this get "_setupTime") > 0 and { isNull _mortar or { !alive _mortar } };
}];

// Called with the task. True when the target can no longer be shelled from the spot
_task set ["_fnc_targetGone", {
    private _target = _this get "_target";
    if (sidesX getVariable [_target, sideUnknown] != teamPlayer) exitWith {true};
    if (_target == "Synd_HQ" and { missionNamespace getVariable ["A3A_petrosMoving", false] }) exitWith {true};
    markerPos _target distance2d (_this get "_mortarPos") > 2600;       // HQ moved away
}];

// Called with [task, impact position]. Houses near the impact can come down, and where the place is not
// spawned the round can kill a garrison soldier or a civilian on paper. Unscheduled.
_task set ["_fnc_impact", {
    params ["_task", "_pos"];
    private _target = _task get "_target";
    if (_pos distance2d markerPos _target > 1.2 * (_task get "_spread")) exitWith {};

    if (random 1 < BUILDING_CHANCE) then {
        private _houses = nearestTerrainObjects [_pos, ["HOUSE", "BUILDING"], 15, true, true] select {
            alive _x and { !(netId _x in A3A_policeStations) } and { !(_x in A3A_antennas) } and { (boundingBoxReal _x) # 2 < 30 }
        };
        if (_houses isNotEqualTo []) then { (_houses # 0) setDamage 1 };
    };

    if (spawner getVariable [_target, 2] != 0 and { _target in A3A_garrison } and { random 1 < TROOP_CHANCE }) then {
        private _troops = A3A_garrison get _target get "troops";
        if (_troops isEqualTo []) exitWith {};
        private _unitType = selectRandom _troops;
        _troops deleteAt (_troops find _unitType);
        [_target] call A3A_fnc_mrkUpdate;
        if (spawner getVariable _target != 2) then { ["remUnitType", [_target, _unitType]] call A3A_fnc_garrisonOp };
        Debug_2("Mortar event: %1 lost a %2 to the barrage", _target, _unitType);
    };

    if (_target in citiesX and { spawner getVariable [_target + "_civ", 2] != 0 } and { random 1 < CIV_CHANCE }) then {
        [CIV_DEATH_SUPPORT, _target, true, true] remoteExecCall ["A3A_fnc_citySupportChange", 2];
        _task set ["_civDeaths", (_task get "_civDeaths") + 1];
    };
}];

// Called with the task. Applies the landed rounds and the civilians the shells really killed
_task set ["_fnc_processHits", {
    private _task = _this;
    isNil {
        private _impacts = +A3A_mortarEventImpacts;
        A3A_mortarEventImpacts = [];
        { [_task, _x] call (_task get "_fnc_impact") } forEach _impacts;

        private _deaths = +A3A_mortarEventCivDeaths;
        A3A_mortarEventCivDeaths = [];
        {
            [CIV_DEATH_SUPPORT, _x, true, true] remoteExecCall ["A3A_fnc_citySupportChange", 2];
        } forEach _deaths;
        _task set ["_civDeaths", (_task get "_civDeaths") + count _deaths];
    };
}];

// Called with the task. Puts the mortar on the ground and a crewman behind it
_task set ["_fnc_setupMortar", {
    private _side = _this get "_side";
    private _faction = Faction(_side);
    private _units = (_this get "_teamUnits") select { _x call A3A_fnc_canFight };
    if (_units isEqualTo []) exitWith {};

    private _mortarType = selectRandom (_faction get "staticMortars");
    private _spot = getPosATL (_units # 0);
    private _pos = _spot findEmptyPosition [0, 20, _mortarType];
    if (_pos isEqualTo []) then { _pos = _spot };
    private _mortar = createVehicle [_mortarType, _pos, [], 0, "NONE"];
    _mortar setDir (_pos getDir markerPos (_this get "_target"));
    [_mortar, _side, "legacy"] call A3A_fnc_AIVEHinit;
    _this set ["_mortar", _mortar];

    private _magType = [_mortarType] call A3A_fnc_getMortarMags select 1 getOrDefault ["HE", ""];
    private _ammoType = if (_magType == "") then { "Sh_82mm_AMOS" } else { getText (configFile >> "CfgMagazines" >> _magType >> "ammo") };
    private _flightTime = _mortar getArtilleryETA [markerPos (_this get "_target"), _magType];
    _this set ["_magType", _magType];
    _this set ["_ammoType", _ammoType];
    _this set ["_flightTime", [_flightTime, 30] select (_flightTime < 0)];

    { _x setUnitPos "MIDDLE"; doStop _x } forEach _units;
    (_units # 0) moveInGunner _mortar;

    _mortar setVariable ["A3A_mortarShots", 0];
    _mortar addEventHandler ["Fired", {
        params ["_mortar", "", "", "", "", "", "_projectile"];
        _mortar setVariable ["A3A_mortarShots", (_mortar getVariable ["A3A_mortarShots", 0]) + 1];
        // Deleted rather than Explode: also fires for modded shells that split into submunitions
        _projectile addEventHandler ["Deleted", { A3A_mortarEventImpacts pushBack getPosATL (_this # 0) }];
    }];

    // Civilians killed by this mortar's shells
    A3A_mortarEventImpacts = [];
    A3A_mortarEventCivDeaths = [];
    A3A_mortarEventMortar = _mortar;
    private _killedEH = addMissionEventHandler ["EntityKilled", {
        params ["_victim", "_killer", "_instigator"];
        if !(_victim isKindOf "CAManBase") exitWith {};
        if (side group _victim != civilian) exitWith {};
        private _mortar = A3A_mortarEventMortar;
        if (isNull _mortar) exitWith {};
        if (_killer != _mortar and { _instigator != _mortar } and { isNull _instigator or { objectParent _instigator != _mortar } }) exitWith {};
        A3A_mortarEventCivDeaths pushBack getPosATL _victim;
    }];
    _this set ["_killedEH", _killedEH];
    Info_2("Mortar event: %1 set up at %2", _mortarType, _pos);
}];

// Called with the task. Gets a team member behind the mortar when the gunner is gone
_task set ["_fnc_manMortar", {
    private _mortar = _this get "_mortar";
    if (alive gunner _mortar) exitWith {true};
    private _units = (_this get "_teamUnits") select { _x call A3A_fnc_canFight and { _x distance _mortar < 60 } };
    if (_units isEqualTo []) exitWith {false};
    private _unit = _units # 0;
    if (_unit distance _mortar < 5) then {
        _unit moveInGunner _mortar;
    } else {
        _unit assignAsGunner _mortar;
        [_unit] orderGetIn true;
    };
    false;
}];

// Called with [mortar, aim position, ammo class]. A round falling on the aim position as if the mortar fired it
_task set ["_fnc_dropShell", {
    params ["_mortar", "_pos", "_ammoType"];
    private _shell = createVehicle [_ammoType, _pos vectorAdd [0, 0, 150], [], 0, "CAN_COLLIDE"];
    _shell setShotParents [_mortar, gunner _mortar];          // kills count as the mortar's
    _shell setVectorDirAndUp [[0, 0, -1], [0, 1, 0]];
    _shell setVelocity [0, 0, -100];
    _shell addEventHandler ["Deleted", { A3A_mortarEventImpacts pushBack getPosATL (_this # 0) }];
    _mortar setVariable ["A3A_mortarShots", (_mortar getVariable ["A3A_mortarShots", 0]) + 1];
    Debug_1("Mortar event: round dropped by script on %1", _pos);
}];

// Called with the task. Sends whoever is left back to base
_task set ["_fnc_retreat", {
    private _mortar = _this get "_mortar";
    private _team = _this get "_team";

    // The team packs the mortar up if they are still with it
    if (alive _mortar and { (_this get "_teamUnits") findIf { _x call A3A_fnc_canFight and { _x distance _mortar < 30 } } != -1 }) then {
        { moveOut _x } forEach crew _mortar;
        deleteVehicle _mortar;
    } else {
        if (!isNull _mortar) then { [_mortar] spawn A3A_fnc_vehDespawner };
    };
    { _x setUnitPos "AUTO" } forEach (_this get "_teamUnits");

    { if (!isNull _x) then { [_x] spawn A3A_fnc_enemyReturnToBase } } forEach [_team, _this get "_escortGroup", _this get "_crewGroup"];
    private _truck = _this get "_truck";
    if (!isNull _truck) then { [_truck] spawn A3A_fnc_vehDespawner };
}];


/////////////////////
// State functions //
/////////////////////

// Waiting for the hidden start time
_task set ["s_waitStart", {
    if (_this call (_this get "_fnc_targetGone")) exitWith {
        _this set ["state", "s_cancel"]; false;
    };
    if (time < _this get "_startTime") exitWith {false};

    _this call (_this get "_fnc_spawnForces");
    _this set ["_giveUpTime", time + GIVE_UP_TIME];
    _this set ["state", "s_approach"];
    _this set ["interval", 3];
    false;
}];

// Mortar team walking to the spot
_task set ["s_approach", {
    _this call (_this get "_fnc_escort");
    if (_this call (_this get "_fnc_mortarStopped")) exitWith {
        _this set ["state", "s_success"]; false;
    };
    if (_this call (_this get "_fnc_targetGone") or { time > _this get "_giveUpTime" }) exitWith {
        _this set ["state", "s_cancel"]; false;
    };

    private _team = _this get "_team";
    private _leader = leader _team;
    private _dist = _leader distance2d (_this get "_mortarPos");
    if (_dist > 60 or { _dist > 25 and { currentWaypoint _team < count waypoints _team } }) exitWith {false};

    { doStop _x } forEach units _team;
    _this set ["_setupTime", time + SETUP_TIME];
    _this set ["state", "s_setup"];
    false;
}];

// Assembling the mortar
_task set ["s_setup", {
    _this call (_this get "_fnc_escort");
    if ((_this get "_teamUnits") findIf { _x call A3A_fnc_canFight } == -1) exitWith {
        _this set ["state", "s_success"]; false;
    };
    if (time < _this get "_setupTime") exitWith {false};

    _this call (_this get "_fnc_setupMortar");
    if (isNull (_this get "_mortar")) exitWith {
        _this set ["state", "s_success"]; false;
    };
    _this set ["_nextShot", time + 5];
    [_this get "_hintTitle", format [localize "STR_A3A_Tasks_EVT_Mortar_firing", _this get "_targetName"], markerPos (_this get "_target"), 1500] call FUNC(hintNear);
    _this set ["state", "s_barrage"];
    _this set ["interval", 1];
    false;
}];

// Firing: one round every 15 seconds, 20 in all
_task set ["s_barrage", {
    _this call (_this get "_fnc_escort");
    _this call (_this get "_fnc_processHits");
    if (_this call (_this get "_fnc_mortarStopped")) exitWith {
        _this set ["state", "s_success"]; false;
    };

    private _mortar = _this get "_mortar";
    private _shots = _mortar getVariable ["A3A_mortarShots", 0];
    if (_shots >= ROUNDS) exitWith {
        if ((_this get "_lastShotTime") == 0) then { _this set ["_lastShotTime", time] };
        // Wait for the last rounds to land before the score is settled
        if (time > (_this get "_lastShotTime") + (_this get "_flightTime") + 10) then {
            _this call (_this get "_fnc_processHits");
            _this set ["state", "s_failure"];
        };
        false;
    };

    // An ordered round the gunner did not fire (out of range, AI refusing) is dropped in by script,
    // so the barrage cannot stall
    private _pending = _this get "_pendingShot";
    if (_pending isNotEqualTo []) then {
        _pending params ["_pendingPos", "_orderTime", "_shotsBefore"];
        if (_shots > _shotsBefore) exitWith { _this set ["_pendingShot", []] };
        if (time < _orderTime + 12) exitWith {};
        _this set ["_pendingShot", []];
        if !(alive gunner _mortar) exitWith {};
        [_mortar, _pendingPos, _this get "_ammoType"] call (_this get "_fnc_dropShell");
        _shots = _shots + 1;
    };

    if (_shots >= ROUNDS or { time < _this get "_nextShot" }) exitWith {false};
    if !(_this call (_this get "_fnc_manMortar")) exitWith {false};

    // First rounds land wide while the crew finds the range, the rest fall across the place
    private _center = markerPos (_this get "_target");
    private _spread = _this get "_spread";
    private _shotPos = if (_shots < 2) then {
        _center getPos [_spread * (1.5 + random 0.5), random 360];
    } else {
        _center getPos [_spread * sqrt random 1, random 360];
    };
    _mortar setVehicleAmmo 1;
    _mortar doArtilleryFire [_shotPos, _this get "_magType", 1];
    _this set ["_pendingShot", [_shotPos, time, _shots]];
    _this set ["_nextShot", time + ROUND_INTERVAL];
    false;
}];

_task set ["s_success", {
    private _mortar = _this get "_mortar";
    private _shots = if (isNull _mortar) then {0} else { _mortar getVariable ["A3A_mortarShots", 0] };
    private _reward = _this get "_reward";
    private _target = _this get "_target";
    private _mortarPos = _this get "_mortarPos";

    [0, _reward] spawn A3A_fnc_resourcesFIA;
    [REWARD_POINTS, false, _mortarPos, PARTICIPANT_RADIUS] call FUNC(rewardPlayers);

    private _hintStr = if (_shots == 0) then {
        private _city = if (_target in citiesX) then { _target } else { [citiesX, markerPos _target] call BIS_fnc_nearestPosition };
        [SUCCESS_SUPPORT, _city] remoteExecCall ["A3A_fnc_citySupportChange", 2];
        format [localize "STR_A3A_Tasks_EVT_Mortar_success", _this get "_targetName", _reward, [_city] call A3A_fnc_localizar];
    } else {
        format [localize "STR_A3A_Tasks_EVT_Mortar_successLate", _shots, _reward];
    };
    [_this get "_hintTitle", _hintStr] remoteExecCall ["A3A_fnc_customHint", call A3A_fnc_playableUnits];
    Info_2("Mortar event on %1 stopped after %2 rounds", _target, _shots);

    [_this get "_taskId", "MORTAR", "SUCCEEDED"] call A3A_fnc_taskSetState;
    _this set ["state", "s_cleanup"]; false;
}];

_task set ["s_failure", {
    private _civDeaths = _this get "_civDeaths";
    private _hintStr = format [localize "STR_A3A_Tasks_EVT_Mortar_failed", _this get "_targetName", _civDeaths];
    [_this get "_hintTitle", _hintStr] remoteExecCall ["A3A_fnc_customHint", call A3A_fnc_playableUnits];
    private _target = _this get "_target";
    Info_2("Mortar event on %1 completed its barrage and killed %2 civilians", _target, _civDeaths);

    [_this get "_taskId", "MORTAR", "FAILED"] call A3A_fnc_taskSetState;
    _this set ["state", "s_cleanup"]; false;
}];

// The target was lost, the HQ moved or the team never made it. Nobody wins or loses anything
_task set ["s_cancel", {
    private _target = _this get "_target";
    Info_1("Mortar event on %1 called off", _target);
    [_this get "_hintTitle", localize "STR_A3A_Tasks_EVT_Mortar_cancelled", _this get "_mortarPos", 2000] call FUNC(hintNear);
    [_this get "_taskId", "CANCELED"] call BIS_fnc_taskSetState;
    _this set ["state", "s_cleanup"]; false;
}];

_task set ["s_cleanup", {
    if ((_this get "_killedEH") >= 0) then {
        removeMissionEventHandler ["EntityKilled", _this get "_killedEH"];
        A3A_mortarEventMortar = objNull;
    };
    private _mortar = _this get "_mortar";
    if (!isNull _mortar) then { _mortar removeAllEventHandlers "Fired" };

    _this call (_this get "_fnc_retreat");
    deleteMarker (_this get "_areaMrk");
    deleteMarker (_this get "_targetMrk");
    [_this get "_taskId", "MORTAR", 600] spawn A3A_fnc_taskDelete;
    true;       // delete the task
}];

_task;
