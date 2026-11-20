/*
Maintainer: Shoter
    Town crisis event. Not posted on the mission board: A3A_tasks_fnc_eventLoop starts it at random.
    From war level 4 on. A rebel town (any support, any population) lacks one of the town upgrades, and trouble is
    coming because of it.
    The players have 20 to 30 minutes (random, whole minutes) to build that upgrade in the town. If it stands by then the task succeeds and
    nothing happens. Otherwise the task fails and the crisis runs for 5 minutes, and nothing can stop it:
        militia post missing - riot: armed townspeople, hostile to every side, fight anyone in the town. Nobody
                               sends troops, it is the locals alone. When it is over the town loses 30 support.
        clinic missing       - plague: the population falls by 30%, linearly over the 5 minutes. Anyone inside
                               the town area has hurt arms and legs and no breath left; out of the area they
                               recover the normal way.
        city office missing  - poverty: the population falls by 15% and the support by 15, linearly over the
                               5 minutes. Every player inside the town area loses 2 € a second.
    Support and population never go below 0 (population is kept at 1 or more, support changes divide by it).
    Support losses go through A3A_fnc_citySupportChange, so a rebel town that drops below 40 support is lost as usual.
    Riot rioters are only spawned while the town is spawned for players. Where nobody is around, the riot happens
    on paper: the support loss still applies.

    Runs in the A3A_tasks_fnc_runTask framework: this file builds the task hashmap and its state functions.

Arguments:
    <ARRAY> Task params from FUNC(EVT_TownCrisis_p): [city marker, upgrade id]
    <ANY> Checkpoint data, unused (task is not saved)

Return Value:
    <HASHMAP> Task

Scope: Server
Environment: Scheduled
Public: No
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

#define DEADLINE_MIN 20
#define DEADLINE_MAX 30
#define CRISIS_TIME 300
#define RIOT_SUPPORT_LOSS 30
#define PLAGUE_POP_LOSS 0.3
#define POVERTY_POP_LOSS 0.15
#define POVERTY_SUPPORT_LOSS 15
#define POVERTY_MONEY_RATE 2
#define RIOTERS_MIN 4
#define RIOTERS_MAX 16
#define RIOTER_GROUP_SIZE 3
#define RIOT_RADIUS 250

params ["_params", "_checkpoint"];
_params params ["_city", "_upgrade"];
Trace_1("Params: %1", _params);

private _crisis = switch (_upgrade) do {
    case "militia": {"riot"};
    case "clinic": {"plague"};
    default {"poverty"};
};

private _task = createHashMap;
_task set ["_city", _city];
_task set ["_upgrade", _upgrade];
_task set ["_crisis", _crisis];
_task set ["_cityName", [_city] call A3A_fnc_localizar];
_task set ["_upgradeName", localize format ["STR_A3A_fn_townUpgrades_name_%1", _upgrade]];
_task set ["_hintTitle", format [localize format ["STR_A3A_Tasks_EVT_TownCrisis_title_%1", _crisis], _task get "_cityName"]];
private _deadlineMin = DEADLINE_MIN + floor random (DEADLINE_MAX - DEADLINE_MIN + 1);
_task set ["_deadline", time + 60 * _deadlineMin];
_task set ["_crisisStart", 0];
_task set ["_lastTick", 0];
_task set ["_pop0", 0];
_task set ["_supportDue", 0];           // support loss scheduled so far (poverty)
_task set ["_supportLost", 0];          // support actually lost, smaller when support hit 0
_task set ["_warned", []];              // UIDs of players already told they are inside the crisis area
_task set ["_rioters", []];
_task set ["_rioterGroups", []];
_task set ["_riotersSpawned", false];

// The map shows the whole town, the crisis covers all of it
private _taskId = "TOWNCRISIS" + str A3A_taskCount;
private _color = ["ColorOrange", "ColorRed"] select (_crisis == "riot");
private _areaMrk = createMarker ["A3A_townCrisisArea_" + _taskId, markerPos _city];
_areaMrk setMarkerShape "ELLIPSE";
_areaMrk setMarkerSize markerSize _city;
_areaMrk setMarkerDir markerDir _city;
_areaMrk setMarkerBrush "FDiagonal";
_areaMrk setMarkerColor _color;
_areaMrk setMarkerAlpha 0.6;
_task set ["_areaMrk", _areaMrk];

private _iconMrk = createMarker ["A3A_townCrisisIcon_" + _taskId, markerPos _city];
_iconMrk setMarkerType "mil_warning";
_iconMrk setMarkerColor _color;
_iconMrk setMarkerText localize format ["STR_A3A_Tasks_EVT_TownCrisis_marker_%1", _crisis];
_task set ["_iconMrk", _iconMrk];

private _taskIcon = switch (_crisis) do {
    case "riot": {"danger"};
    case "plague": {"heal"};
    default {"documents"};
};
private _taskDesc = format [localize format ["STR_A3A_Tasks_EVT_TownCrisis_desc_%1", _crisis], _task get "_cityName", _task get "_upgradeName", [_deadlineMin] call FUNC(minutesFromNow)];
[[teamPlayer, civilian], _taskId, [_taskDesc, _task get "_hintTitle", _areaMrk], markerPos _city, false, 0, true, _taskIcon, true] call BIS_fnc_taskCreate;
[_taskId, "TOWNCRISIS", "CREATED"] remoteExecCall ["A3A_fnc_taskUpdate", 2];
_task set ["_taskId", _taskId];
// Everybody gets the full briefing at once
[_task get "_hintTitle", _taskDesc] remoteExecCall ["A3A_fnc_customHint", call A3A_fnc_playableUnits];

_task set ["state", "s_wait"];
_task set ["interval", 5];

Info_3("Town crisis event: %1 in %2, missing %3", _crisis, _city, _upgrade);


//////////////////////
// Helper functions //
//////////////////////

// Called with [task, population loss as a fraction of the population when the crisis started]
_task set ["_fnc_reducePopulation", {
    params ["_task", "_lossFraction"];
    private _city = _task get "_city";
    private _pop0 = _task get "_pop0";
    private _progress = ((time - (_task get "_crisisStart")) / CRISIS_TIME) min 1;
    private _target = 1 max round (_pop0 - _pop0 * _lossFraction * _progress);
    isNil {
        private _data = +(A3A_cityData getVariable _city);
        if (_data # 0 <= _target) exitWith {};
        _data set [0, _target];
        A3A_cityData setVariable [_city, _data, true];
    };
}];

// Called with [task, support loss]. Takes up to that much support, never below 0
_task set ["_fnc_takeSupport", {
    params ["_task", "_amount"];
    private _city = _task get "_city";
    isNil {
        private _support = (A3A_cityData getVariable _city) # 1;
        private _loss = _amount min _support;
        if (_loss <= 0) exitWith {};
        [-_loss, _city, false] call A3A_fnc_citySupportChange;
        _task set ["_supportLost", (_task get "_supportLost") + _loss];
    };
}];

// Called with the task. Players inside the town area
_task set ["_fnc_playersInTown", {
    private _city = _this get "_city";
    (allPlayers - entities "HeadlessClient_F") select { alive _x and { _x inArea _city } };
}];

// Called with [task, players]. Tells players who just walked into the crisis area what it does to them
_task set ["_fnc_warnPlayers", {
    params ["_task", "_players"];
    private _warned = _task get "_warned";
    private _new = _players select { !(getPlayerUID _x in _warned) };
    if (_new isEqualTo []) exitWith {};
    _warned append (_new apply { getPlayerUID _x });
    private _text = format [localize format ["STR_A3A_Tasks_EVT_TownCrisis_inside_%1", _task get "_crisis"], _task get "_cityName"];
    [_task get "_hintTitle", _text] remoteExecCall ["A3A_fnc_customHint", _new];
}];

// Called with the task. Arms the townspeople. They are renegades: hostile to every side and every side to them
_task set ["_fnc_spawnRioters", {
    private _city = _this get "_city";
    private _numCiv = (A3A_cityData getVariable _city) # 0;
    private _count = RIOTERS_MAX min (RIOTERS_MIN + round (sqrt _numCiv / 2));
    private _radius = ((markerSize _city) # 0) min RIOT_RADIUS;
    private _places = [_city, _radius, _count, RIOTER_GROUP_SIZE] call A3A_fnc_patrolGetBuildingPlaces;
    private _unitType = A3A_faction_reb get "unitUnarmed";
    private _rioters = _this get "_rioters";
    private _groups = _this get "_rioterGroups";

    private _group = grpNull;
    for "_i" from 1 to _count do {
        private _place = _places deleteAt 0;
        if (isNil "_place") then { _place = [markerPos _city getPos [_radius * sqrt random 1, random 360], random 360] };
        if (isNull _group or { count units _group >= RIOTER_GROUP_SIZE } or { leader _group distance2d (_place # 0) > 40 }) then {
            _group = createGroup [civilian, true];
            _groups pushBack _group;
        };
        private _identity = [A3A_faction_civ, _unitType] call A3A_fnc_createRandomIdentity;
        private _unit = [_group, _unitType, _place # 0, [], 0, "NONE", _identity] call A3A_fnc_createUnit;
        _unit setDir (_place # 1);
        _unit forceAddUniform selectRandom (A3A_faction_civ get "uniforms");
        _unit addHeadgear selectRandom (A3A_faction_civ get "headgear");
        [_unit, "Rifles" call A3A_fnc_randomRifle, "OpticsClose", 50] call A3A_fnc_addPrimaryAndMags;
        _unit setSkill 0.4;
        _unit allowFleeing 0;
        _unit setVariable ["A3A_rioter", true];
        _unit addRating -10000;

        // Renegades are hostile to each other too: rioters do not hurt rioters
        _unit addEventHandler ["HandleDamage", {
            params ["_unit", "", "", "_source", "", "_hitIndex", "_instigator"];
            private _shooter = [_instigator, _source] select (isNull _instigator);
            if (_shooter == _unit or { !(_shooter getVariable ["A3A_rioter", false]) }) exitWith { nil };
            if (_hitIndex < 0) then { damage _unit } else { _unit getHitIndex _hitIndex };
        }];
        _rioters pushBack _unit;
        sleep 0.1;
    };

    // Groups ignore the other rioters, so they look for other targets (game versions that have the command)
    if (supportInfo "b:GROUP ignoretarget ARRAY" isNotEqualTo []) then {
        private _fnc_ignore = compile "params ['_groups', '_units']; { private _group = _x; { _group ignoreTarget [_x, true] } forEach _units } forEach _groups;";
        [_groups, _rioters] call _fnc_ignore;
    };

    {
        _x setBehaviourStrong "COMBAT";
        _x setCombatMode "RED";
        _x setSpeedMode "FULL";
    } forEach _groups;
    _this set ["_riotersSpawned", true];
    Info_2("Town crisis event: %1 rioters armed in %2", _count, _city);
}];

// Called with the task every tick of the riot. Keeps the rioters hostile and roaming the town
_task set ["_fnc_riot", {
    private _city = _this get "_city";
    private _radius = ((markerSize _city) # 0) min RIOT_RADIUS;
    {
        // Kills raise the rating, a rioter must not become friendly halfway through
        if (alive _x and { rating _x > -5000 }) then { _x addRating -10000 };
    } forEach (_this get "_rioters");
    {
        if (units _x findIf { alive _x } == -1) then { continue };
        if (currentWaypoint _x < count waypoints _x) then { continue };
        private _wp = _x addWaypoint [markerPos _city getPos [_radius * sqrt random 1, random 360], 0];
        _wp setWaypointType "SAD";
        _wp setWaypointCompletionRadius 20;
    } forEach (_this get "_rioterGroups");
}];

// Called with the task. The rioters put their weapons away and are ordinary civilians again
_task set ["_fnc_pacify", {
    {
        if (!alive _x) then { continue };
        removeAllWeapons _x;
        _x addRating (-rating _x);
        _x setVariable ["A3A_rioter", nil];
    } forEach (_this get "_rioters");
    {
        private _group = _x;
        if (units _group findIf { alive _x } == -1) then { continue };
        for "_i" from (count waypoints _group - 1) to 1 step -1 do { deleteWaypoint [_group, _i] };
        _group addWaypoint [getPosATL leader _group, 0];        // stop where they are
        _group setBehaviourStrong "CARELESS";
        _group setCombatMode "BLUE";
        _group setSpeedMode "LIMITED";
    } forEach (_this get "_rioterGroups");
}];

// Called with the task every tick of the plague. Sickens everybody inside the town on the machine that owns them
_task set ["_fnc_plague", {
    private _city = _this get "_city";
    private _byOwner = createHashMap;
    {
        private _owner = owner _x;
        private _list = _byOwner getOrDefault [_owner, []];
        if (_list isEqualTo []) then { _byOwner set [_owner, _list] };
        _list pushBack _x;
    } forEach (allUnits inAreaArray _city);
    { [_y] remoteExecCall [QFUNC(EVT_TownCrisis_sicken), _x] } forEach _byOwner;
}];

// Called with [task, players inside the town, seconds since the last tick]. Each player loses money, not below 0
_task set ["_fnc_poverty", {
    params ["_task", "_players", "_dt"];
    private _amount = round (POVERTY_MONEY_RATE * _dt);
    if (_amount <= 0) exitWith {};
    {
        private _player = _x;
        isNil {
            private _money = _player getVariable ["moneyX", 0];
            private _loss = _amount min _money;
            if (_loss <= 0) exitWith {};
            _player setVariable ["moneyX", _money - _loss, true];
            [] remoteExec ["A3A_fnc_statistics", _player];
        };
    } forEach _players;
}];


/////////////////////
// State functions //
/////////////////////

// 20-30 minutes for the players to build the missing upgrade
_task set ["s_wait", {
    private _city = _this get "_city";
    if ([_city, _this get "_upgrade"] call A3A_fnc_townUpgradeHas) exitWith {
        _this set ["state", "s_success"]; false;
    };
    if (sidesX getVariable [_city, sideUnknown] != teamPlayer or { _city in destroyedSites }) exitWith {
        _this set ["state", "s_cancel"]; false;
    };
    if (time < _this get "_deadline") exitWith {false};

    _this set ["state", "s_startCrisis"];
    false;
}];

_task set ["s_startCrisis", {
    private _city = _this get "_city";
    private _crisis = _this get "_crisis";
    _this set ["_crisisStart", time];
    _this set ["_lastTick", time];
    _this set ["_pop0", (A3A_cityData getVariable _city) # 0];

    private _taskId = _this get "_taskId";
    private _desc = format [localize format ["STR_A3A_Tasks_EVT_TownCrisis_started_%1", _crisis], _this get "_cityName"];
    [_taskId, [_desc, _this get "_hintTitle", _this get "_areaMrk"]] call BIS_fnc_taskSetDescription;
    [_taskId, "TOWNCRISIS", "FAILED"] call A3A_fnc_taskSetState;
    [_this get "_hintTitle", _desc] remoteExecCall ["A3A_fnc_customHint", call A3A_fnc_playableUnits];
    Info_2("Town crisis event: %1 broke out in %2", _crisis, _city);

    _this set ["state", "s_crisis"];
    _this set ["interval", 2];
    false;
}];

// Five minutes of crisis, nothing stops it
_task set ["s_crisis", {
    private _city = _this get "_city";
    private _progress = ((time - (_this get "_crisisStart")) / CRISIS_TIME) min 1;
    private _dt = time - (_this get "_lastTick");
    _this set ["_lastTick", time];

    switch (_this get "_crisis") do {
        case "riot": {
            if (!(_this get "_riotersSpawned") and { spawner getVariable [_city, 2] == 0 }) then {
                _this call (_this get "_fnc_spawnRioters");
            };
            _this call (_this get "_fnc_riot");
        };
        case "plague": {
            [_this, PLAGUE_POP_LOSS] call (_this get "_fnc_reducePopulation");
            _this call (_this get "_fnc_plague");
            [_this, _this call (_this get "_fnc_playersInTown")] call (_this get "_fnc_warnPlayers");
        };
        case "poverty": {
            [_this, POVERTY_POP_LOSS] call (_this get "_fnc_reducePopulation");
            private _due = POVERTY_SUPPORT_LOSS * _progress;
            [_this, _due - (_this get "_supportDue")] call (_this get "_fnc_takeSupport");
            _this set ["_supportDue", _due];
            private _players = _this call (_this get "_fnc_playersInTown");
            [_this, _players, _dt] call (_this get "_fnc_poverty");
            [_this, _players] call (_this get "_fnc_warnPlayers");
        };
    };

    if (_progress < 1 and { !(_city in destroyedSites) }) exitWith {false};
    _this set ["state", "s_endCrisis"];
    false;
}];

_task set ["s_endCrisis", {
    private _city = _this get "_city";
    private _crisis = _this get "_crisis";
    if (_crisis == "riot") then {
        [_this, RIOT_SUPPORT_LOSS] call (_this get "_fnc_takeSupport");
        _this call (_this get "_fnc_pacify");
    };

    private _popLost = (_this get "_pop0") - ((A3A_cityData getVariable _city) # 0);
    private _supportLost = round (_this get "_supportLost");
    private _hintStr = format [localize format ["STR_A3A_Tasks_EVT_TownCrisis_ended_%1", _crisis], _this get "_cityName", _popLost, _supportLost];
    [_this get "_hintTitle", _hintStr] remoteExecCall ["A3A_fnc_customHint", call A3A_fnc_playableUnits];
    [_this get "_taskId", [_hintStr, _this get "_hintTitle", _this get "_areaMrk"]] call BIS_fnc_taskSetDescription;
    Info_4("Town crisis event: %1 in %2 is over, %3 people and %4 support lost", _crisis, _city, _popLost, _supportLost);

    _this set ["state", "s_cleanup"];
    false;
}];

_task set ["s_success", {
    private _hintStr = format [localize "STR_A3A_Tasks_EVT_TownCrisis_success", _this get "_cityName", _this get "_upgradeName"];
    [_this get "_hintTitle", _hintStr] remoteExecCall ["A3A_fnc_customHint", call A3A_fnc_playableUnits];
    private _city = _this get "_city";
    Info_1("Town crisis event in %1 averted", _city);

    [_this get "_taskId", "TOWNCRISIS", "SUCCEEDED"] call A3A_fnc_taskSetState;
    _this set ["state", "s_cleanup"]; false;
}];

// The town is no longer ours before the deadline. Nobody wins or loses anything
_task set ["s_cancel", {
    private _city = _this get "_city";
    Info_1("Town crisis event in %1 called off, the town is no longer rebel", _city);
    [_this get "_hintTitle", format [localize "STR_A3A_Tasks_EVT_TownCrisis_cancelled", _this get "_cityName"], markerPos _city, 2000] call FUNC(hintNear);
    [_this get "_taskId", "CANCELED"] call BIS_fnc_taskSetState;
    _this set ["state", "s_cleanup"]; false;
}];

_task set ["s_cleanup", {
    deleteMarker (_this get "_areaMrk");
    deleteMarker (_this get "_iconMrk");

    // Former rioters and their dead go once nobody is around to see it
    private _rioters = _this get "_rioters";
    if (_rioters isNotEqualTo []) then {
        [_this get "_city", _rioters] spawn {
            params ["_city", "_rioters"];
            waitUntil { sleep 10; spawner getVariable [_city, 2] != 0 };
            { deleteVehicle _x } forEach _rioters;
        };
    };

    [_this get "_taskId", "TOWNCRISIS", 600] spawn A3A_fnc_taskDelete;
    true;       // delete the task
}];

_task;
