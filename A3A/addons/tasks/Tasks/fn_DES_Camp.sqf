/*
Maintainer: Shoter
    Enemy camp task. An enemy squad has pitched camp out in the woods. The map only shows the area it is in.
    The soldiers spawn once rebels come within spawn distance: the squad sits around the campfire while two
    sentries walk the perimeter. They get up and fight once they notice us, are shot at or someone walks right up.
    When no defender is left standing near the fire, a player burns the camp with a hold action on the campfire.
    Every player who took part (came within 300m of the camp) gets 100 € per war level.

    Runs in the A3A_tasks_fnc_runTask framework: this file builds the task hashmap and its state functions.

Arguments:
    <ARRAY> Task params from FUNC(DES_Camp_p): [camp position ATL, enemy side]
    <ANY> Checkpoint data, unused (task is not saved)

Return Value:
    <HASHMAP> Task

Scope: Server
Environment: Scheduled
Public: No
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

#define SIT_ANIM "AmovPsitMstpSlowWrflDnon"
#define STAND_UP_ANIM "AmovPsitMstpSlowWrflDnon_AmovPercMstpSlowWrflDnon"
#define FIDGET_ANIMS ["AmovPsitMstpSlowWrflDnon_Smoking", "AmovPsitMstpSlowWrflDnon_WeaponCheck1", "AmovPsitMstpSlowWrflDnon_WeaponCheck2"]
#define SITTER_AI ["ANIM", "MOVE", "PATH", "FSM", "AUTOTARGET", "TARGET"]
#define PARTICIPANT_RADIUS 300
#define DEFENDER_RADIUS 150

params ["_params", "_checkpoint"];
_params params ["_campPos", "_side"];
Trace_1("Params: %1", _params);

private _faction = Faction(_side);

private _task = createHashMap;
_task set ["_hintTitle", localize "STR_A3A_Tasks_DES_Camp_title"];
_task set ["_campPos", _campPos];
_task set ["_side", _side];
_task set ["_endTime", time + 60*60];
_task set ["_participants", []];            // UIDs of players who came near the camp
_task set ["_sitters", []];
_task set ["_jipIds", []];                  // JIP ids of the broadcast sitting animations
_task set ["_groups", []];
_task set ["_alerted", false];
_task set ["_cleared", false];
_task set ["_nextFidget", 0];

// Make room for the camp: hide the trees and bushes on the spot, they come back at cleanup
private _hiddenTerrain = nearestTerrainObjects [_campPos, ["TREE", "SMALL TREE", "BUSH"], 11, false, true];
{ _x hideObjectGlobal true } forEach _hiddenTerrain;
_task set ["_hiddenTerrain", _hiddenTerrain];

// Camp props, laid out around the fire. [type, distance from the fire, angle, extra rotation]
private _rot = random 360;
private _layout = [
    ["Land_TentA_F", 7.5, 0, 0],
    ["Land_TentDome_F", 8, 115, 0],
    ["Land_TentA_F", 7.5, 235, 0],
    ["Land_Sleeping_bag_F", 5.2, 50, 90],
    ["Land_Sleeping_bag_brown_F", 5.2, 175, 90],
    ["Land_WoodPile_F", 4.5, 295, 90],
    ["Land_Axe_fire_F", 3.8, 310, 0],
    ["Land_Camping_Light_F", 6, 20, 0],
    ["Land_BakedBeans_F", 1.2, 80, 0],
    ["Land_Canteen_F", 1.3, 200, 0],
    ["Land_CampingTable_small_F", 6.5, 270, 0]
];
private _objects = [];
private _tents = [];
{
    _x params ["_type", "_dist", "_angle", "_turn"];
    private _pos = _campPos getPos [_dist, _rot + _angle];
    _pos set [2, 0];
    private _obj = createVehicle [_type, _pos, [], 0, "CAN_COLLIDE"];
    _obj setDir ((_pos getDir _campPos) + _turn);
    _obj setVectorUp surfaceNormal _pos;
    _obj enableSimulationGlobal false;
    _objects pushBack _obj;
    if (_type in ["Land_TentA_F", "Land_TentDome_F", "Land_Sleeping_bag_F", "Land_Sleeping_bag_brown_F", "Land_CampingTable_small_F"]) then { _tents pushBack _obj };
} forEach _layout;
_task set ["_objects", _objects];
_task set ["_tents", _tents];

private _fire = createVehicle ["Campfire_burning_F", _campPos, [], 0, "CAN_COLLIDE"];
_fire setVectorUp surfaceNormal _campPos;
_task set ["_fire", _fire];

// Their supplies, free for the taking
private _cratePos = _campPos getPos [9.5, _rot + 175];
_cratePos set [2, 0];
private _crate = createVehicle [_faction get "ammobox", _cratePos, [], 0, "CAN_COLLIDE"];
_crate setDir (_cratePos getDir _campPos);
// Otherwise when destroyed, ammoboxes sink 100m underground and are never cleared up
_crate addEventHandler ["Killed", { [_this#0] spawn { sleep 10; deleteVehicle (_this#0) } }];
[_crate] spawn A3A_fnc_fillLootCrate;
[_crate] call A3A_Logistics_fnc_addLoadAction;
_task set ["_crate", _crate];
_task set ["_cratePos", _cratePos];

// Burn the camp once it has been cleared. The server sets A3A_campCleared on the fire
[
    _fire,
    localize "STR_A3A_Tasks_DES_Camp_burnAction",
    "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_secure_ca.paa",
    "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_secure_ca.paa",
    "(_this distance _target < 5) and (_target getVariable ['A3A_campCleared', false]) and (isNil {_target getVariable 'A3A_campBurnedBy'})",
    "(_caller distance _target < 5) and (_target getVariable ['A3A_campCleared', false])",
    {},
    {},
    { _target setVariable ["A3A_campBurnedBy", _caller, true] },
    {},
    [],
    8,
    10,
    true,
    false
] remoteExec ["BIS_fnc_holdActionAdd", 0, _fire];

// The map only shows roughly where the camp is
private _taskId = "DES" + str A3A_taskCount;
private _areaPos = _campPos getPos [random 150, random 360];
private _areaMrk = createMarker ["A3A_campArea_" + _taskId, _areaPos];
_areaMrk setMarkerShape "ELLIPSE";
_areaMrk setMarkerSize [250, 250];
_areaMrk setMarkerBrush "FDiagonal";
_areaMrk setMarkerColor "ColorRed";
_areaMrk setMarkerAlpha 0.6;
_task set ["_areaMrk", _areaMrk];

private _nearTown = [citiesX, _campPos] call BIS_fnc_nearestPosition;
private _displayTime = [((_task get "_endTime") - time) / 60] call FUNC(minutesFromNow);
private _taskDesc = format [localize "STR_A3A_Tasks_DES_Camp_desc", _faction get "name", _nearTown, _displayTime, 100 * tierWar];
[[teamPlayer, civilian], _taskId, [_taskDesc, _task get "_hintTitle", _areaMrk], _areaPos, false, 0, true, "Destroy", true] call BIS_fnc_taskCreate;
[_taskId, "DES", "CREATED"] remoteExecCall ["A3A_fnc_taskUpdate", 2];
_task set ["_taskId", _taskId];

_task set ["state", "s_waitForRebels"];
_task set ["interval", 5];

Trace_1("Initial data: %1", _task);


//////////////////////
// Helper functions //
//////////////////////

// Called with the task. Spawns the squad around the fire and the sentries
_task set ["_fnc_spawnSoldiers", {
    private _side = _this get "_side";
    private _faction = Faction(_side);
    private _campPos = _this get "_campPos";

    private _squadTypes = _faction get (["groupsMilitiaSquads", "groupsSquads"] select (random 10 < tierWar));
    if (_squadTypes isEqualTo []) then { _squadTypes = _faction get "groupsSquads" };
    private _campGroup = [_campPos getPos [14, random 360], _side, selectRandom _squadTypes] call A3A_fnc_spawnGroup;
    private _sentries = [_campPos getPos [25, random 360], _side, _faction get "groupSentry"] call A3A_fnc_spawnGroup;
    {
        private _group = _x;
        { [_x, ""] call A3A_fnc_NATOinit } forEach units _group;
    } forEach [_campGroup, _sentries];
    _this set ["_groups", [_campGroup, _sentries]];

    // The squad sits in a ring around the fire, facing it
    _campGroup setBehaviourStrong "SAFE";
    private _sitters = units _campGroup;
    private _count = count _sitters;
    private _radius = 2.1 + 0.12 * _count;
    private _rot = random 360;
    {
        private _unit = _x;
        private _angle = _rot + _forEachIndex * 360 / (_count max 1);
        private _pos = _campPos getPos [_radius, _angle];
        { _unit disableAI _x } forEach SITTER_AI;
        _unit setPosATL [_pos # 0, _pos # 1, 0];
        _unit setDir (_angle + 180);
        // switchMove only plays where it runs, so broadcast it and keep it for JIP until the unit gets up
        private _jipId = "A3A_campSit_" + netId _unit;
        (_this get "_jipIds") pushBack _jipId;
        [_unit, SIT_ANIM] remoteExec ["switchMove", 0, _jipId];
        _unit addEventHandler ["FiredNear", { (_this # 0) setVariable ["A3A_campAlert", true] }];
    } forEach _sitters;
    _this set ["_sitters", _sitters];

    [_sentries, "Patrol_Area", 20, 45, 80, true, _campPos, false] call A3A_fnc_patrolLoop;
    private _sentryCount = count units _sentries;
    Debug_3("Enemy camp at %1 spawned with %2 sitting and %3 sentries", _campPos, _count, _sentryCount);
}];

// Called with the task. True once the camp has noticed us
_task set ["_fnc_isAlerted", {
    private _campPos = _this get "_campPos";
    private _sitters = _this get "_sitters";
    if (_sitters findIf {
        !alive _x or damage _x > 0 or _x getVariable ["A3A_campAlert", false]
        or { !isNull (_x findNearestEnemy _x) }
    } != -1) exitWith {true};

    private _sentries = (_this get "_groups") param [1, grpNull];
    if (units _sentries findIf { alive _x and behaviour _x == "COMBAT" } != -1) exitWith {true};

    // Somebody walking right into the camp, unless they are undercover
    (units teamPlayer inAreaArray [_campPos, 12, 12]) findIf { alive _x and !captive _x } != -1;
}];

// Called with the task. Lets the sitting soldiers get up and move again
_task set ["_fnc_release", {
    params ["_task", "_combat"];
    {
        private _unit = _x;
        { _unit enableAI _x } forEach SITTER_AI;
        // Only from the sitting pose, not from unconscious or dead
        if (alive _unit and { animationState _unit select [0, 8] == "amovpsit" }) then { _unit playMoveNow STAND_UP_ANIM };
    } forEach (_task get "_sitters");
    { remoteExec ["", _x] } forEach (_task get "_jipIds");
    _task set ["_jipIds", []];

    private _campGroup = (_task get "_groups") param [0, grpNull];
    if (_combat and !isNull _campGroup) then {
        _campGroup setBehaviourStrong "COMBAT";
        _campGroup setCombatMode "RED";
    };
}];

// Spawned on the server on success: the tents go up in flames
_task set ["_fnc_burn", {
    params ["_tents"];
    private _fires = [];
    {
        if (typeOf _x in ["Land_TentA_F", "Land_TentDome_F"]) then {
            _fires pushBack createVehicle ["test_EmptyObjectForFireBig", getPosATL _x, [], 0, "CAN_COLLIDE"];
        };
    } forEach _tents;
    sleep 30;
    { deleteVehicle _x } forEach _tents;
    sleep 150;
    { deleteVehicle _x } forEach _fires;
}];

// Spawned on the server at cleanup: removes the camp once no rebel is around any more
_task set ["_fnc_despawnCamp", {
    params ["_campPos", "_objects", "_crate", "_cratePos", "_hiddenTerrain"];
    waitUntil { sleep 30; !([distanceSPWN, 1, _campPos, teamPlayer] call A3A_fnc_distanceUnits) };
    { deleteVehicle _x } forEach _objects;
    // Leave the crate alone if the players took it with them
    if (!isNull _crate and { _crate distance2d _cratePos < 20 and isNull attachedTo _crate }) then { deleteVehicle _crate };
    { _x hideObjectGlobal false } forEach _hiddenTerrain;
}];


/////////////////////
// State functions //
/////////////////////

// Nothing is spawned but the props until a rebel comes within spawn distance
_task set ["s_waitForRebels", {
    if (time > _this get "_endTime") exitWith {
        _this set ["state", "s_failure"]; false;
    };
    if !([distanceSPWN, 1, _this get "_campPos", teamPlayer] call A3A_fnc_distanceUnits) exitWith {false};

    _this call (_this get "_fnc_spawnSoldiers");
    _this set ["_nextFidget", time + 20];
    _this set ["state", "s_camp"];
    _this set ["interval", 2];
    false;
}];

_task set ["s_camp", {
    private _campPos = _this get "_campPos";
    private _fire = _this get "_fire";

    // Anyone who comes near the camp counts as taking part, even if they die or leave before the end
    private _participants = _this get "_participants";
    {
        _participants pushBackUnique getPlayerUID _x;
    } forEach (call A3A_fnc_playableUnits inAreaArray [_campPos, PARTICIPANT_RADIUS, PARTICIPANT_RADIUS]);

    if (!isNil { _fire getVariable "A3A_campBurnedBy" }) exitWith {
        _this set ["state", "s_success"]; false;
    };

    if (!(_this get "_alerted")) then {
        if (_this call (_this get "_fnc_isAlerted")) then {
            _this set ["_alerted", true];
            [_this, true] call (_this get "_fnc_release");
            Debug_1("Enemy camp at %1 alerted", _campPos);
        } else {
            // Now and then somebody at the fire lights a cigarette or checks their rifle
            if (time > _this get "_nextFidget") then {
                _this set ["_nextFidget", time + 15 + random 30];
                private _sitters = (_this get "_sitters") select { alive _x };
                if (_sitters isNotEqualTo []) then { selectRandom _sitters playMove selectRandom FIDGET_ANIMS };
            };
        };
    };

    // The camp is clear when none of its soldiers can fight near the fire
    private _defenders = [];
    { _defenders append units _x } forEach (_this get "_groups");
    private _cleared = _defenders findIf { _x call A3A_fnc_canFight and { _x distance2d _campPos < DEFENDER_RADIUS } } == -1;
    if (_cleared isNotEqualTo (_this get "_cleared")) then {
        _this set ["_cleared", _cleared];
        _fire setVariable ["A3A_campCleared", _cleared, true];
        if (_cleared) then {
            [_this get "_hintTitle", localize "STR_A3A_Tasks_DES_Camp_cleared", _campPos, 500] call FUNC(hintNear);
        };
    };

    // Out of time. Keep going while players are still at it, up to 20 extra minutes
    private _endTime = _this get "_endTime";
    if (time > _endTime and { time > _endTime + 20*60 or call A3A_fnc_playableUnits inAreaArray [_campPos, 500, 500] isEqualTo [] }) exitWith {
        _this set ["state", "s_failure"]; false;
    };
    false;
}];

_task set ["s_success", {
    private _campPos = _this get "_campPos";
    private _reward = 100 * tierWar;

    // Pay everyone who took part and is still on the server
    private _participants = _this get "_participants";
    private _paidPlayers = (call A3A_fnc_playableUnits) select { getPlayerUID _x in _participants };
    { [_reward, _x] call A3A_fnc_resourcesPlayer } forEach _paidPlayers;
    Info_2("Enemy camp at %1 burned, paid %2 players", _campPos, count _paidPlayers);

    if (_paidPlayers isNotEqualTo []) then {
        [_this get "_hintTitle", format [localize "STR_A3A_Tasks_DES_Camp_success", _reward]] remoteExecCall ["A3A_fnc_customHint", _paidPlayers];
    };

    [_this get "_tents"] spawn (_this get "_fnc_burn");
    [_this get "_taskId", "SUCCEEDED", _campPos, 500] call FUNC(taskNotifyNear);
    [_this get "_taskId", "DES", "SUCCEEDED"] call A3A_fnc_taskSetState;
    _this set ["state", "s_cleanup"]; false;
}];

_task set ["s_failure", {
    [_this get "_hintTitle", localize "STR_A3A_Tasks_DES_Camp_timeout", _this get "_campPos", 1000] call FUNC(hintNear);
    [_this get "_taskId", "DES", "FAILED"] call A3A_fnc_taskSetState;
    _this set ["state", "s_cleanup"]; false;
}];

_task set ["s_cleanup", {
    // Soldiers who never noticed us get up and leave with the rest
    if (!(_this get "_alerted")) then { [_this, false] call (_this get "_fnc_release") };
    { if (!isNull _x) then { [_x] spawn A3A_fnc_groupDespawner } } forEach (_this get "_groups");

    deleteMarker (_this get "_areaMrk");
    private _objects = (_this get "_objects") + [_this get "_fire"];
    [_this get "_campPos", _objects, _this get "_crate", _this get "_cratePos", _this get "_hiddenTerrain"] spawn (_this get "_fnc_despawnCamp");
    [_this get "_taskId", "DES", 1200] spawn A3A_fnc_taskDelete;
    true;       // delete the task
}];

_task;
