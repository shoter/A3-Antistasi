/*
Maintainer: Shoter
    Buying intel task. An enemy officer waits in a house in one of their towns, ready to sell intel for a bribe.
    A civilian supply truck spawns at HQ, locked until players load the bribe into it from their own money
    (truck action, see A3A_tasks_fnc_LOG_BuyIntel_deposit and A3A_GUI_fnc_buyIntelDialog). Players drive it to the
    officer, park it within 20m of him and hand the bribe over in person. He then drives off to his outpost, and we
    get a large intel roll on his side. No money or support reward: the truck is ours to keep.

    The officer only deals with undercover rebels. If a rebel who is not undercover is spotted in the town, he gets in
    his car and drives back to his outpost; if he sees one coming at him (or takes a hit), he fights. Either way the
    deal is off. Bribe money still in the truck when the task fails goes back to the faction funds once the truck
    is driven back to HQ.

    Runs in the A3A_tasks_fnc_runTask framework: this file builds the task hashmap and its state functions.

Arguments:
    <ARRAY> Task params from FUNC(LOG_BuyIntel_p): [town marker, house object, car position ATL, car direction, outpost marker]
    <ANY> Checkpoint data, unused (task is not saved)

Return Value:
    <HASHMAP> Task

Scope: Server
Environment: Scheduled
Public: No
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

#define BRIBE_COST 1000
#define TRUCK_RANGE 20
#define FIGHT_RANGE 50
#define DURATION (90*60)

params ["_params", "_checkpoint"];
_params params ["_city", "_house", "_carPos", "_carDir", "_destMrk"];
Trace_1("Params: %1", _params);

private _side = sidesX getVariable _city;
if !(_side in [Occupants, Invaders]) then { _side = Occupants };
private _faction = Faction(_side);

private _task = createHashMap;
_task set ["_hintTitle", localize "STR_A3A_Tasks_LOG_BuyIntel_title"];
_task set ["_city", _city];
_task set ["_cityName", [_city] call A3A_fnc_localizar];
_task set ["_cityRadius", ([_city] call A3A_fnc_sizeMarker) max 200];
_task set ["_side", _side];
_task set ["_destMrk", _destMrk];
_task set ["_endTime", time + DURATION];

// The officer's car, players can't take it
private _carTypes = _faction getOrDefault ["vehiclesLightUnarmed", []];
if (_carTypes isEqualTo []) then { _carTypes = _faction getOrDefault ["vehiclesPolice", []] };
if (_carTypes isEqualTo []) then { _carTypes = ["C_Offroad_01_F"] };
private _car = objNull;
isNil {
    _car = createVehicle [selectRandom _carTypes, _carPos, [], 0, "CAN_COLLIDE"];
    _car setDir _carDir;
};
[_car, _side] call A3A_fnc_AIVEHinit;
_car lock 3;            // locked for players only
_task set ["_car", _car];

// The officer, on the ground floor of the house, at the spot closest to his car
private _positions = (_house buildingPos -1) select { !surfaceIsWater _x and _x # 2 < 1 };
if (_positions isEqualTo []) then { _positions = [getPosATL _house] };
private _distances = _positions apply { _x distance2d _carPos };
private _officerPos = _positions # (_distances find selectMin _distances);
private _group = createGroup [_side, true];
private _officer = [_group, _faction get "unitOfficial", _officerPos, [], 0, "CAN_COLLIDE"] call A3A_fnc_createUnit;
_officer setPosATL _officerPos;
_officer setDir (_officerPos getDir _carPos);
[_officer, "", false, "legacy"] call A3A_fnc_NATOinit;
_officer disableAI "PATH";
_officer allowFleeing 0;
_officer addEventHandler ["Hit", {
    (_this # 0) setVariable ["A3A_unitHit", true];
    (_this # 0) removeEventHandler [_thisEvent, _thisEventHandler];
}];
_group addVehicle _car;
_group setBehaviourStrong "SAFE";
_task set ["_group", _group];
_task set ["_officer", _officer];

// The server picks up A3A_buyIntelPaidBy on its next tick
[
    _officer,
    localize "STR_A3A_Tasks_LOG_BuyIntel_bribeAction",
    "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_talk_ca.paa",
    "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_talk_ca.paa",
    "alive _target and captive _this and (_this distance _target < 3) and (_target getVariable ['A3A_buyIntelReady', false])",
    "alive _target and (_caller distance _target < 3)",
    {},
    {},
    { _target setVariable ["A3A_buyIntelPaidBy", _caller, true] },
    {},
    [],
    3,
    10,
    true,
    false
] remoteExec ["BIS_fnc_holdActionAdd", 0, _officer];

// Money truck at HQ, locked until the whole bribe is loaded
private _truckTypes = FactionGet(reb, "vehiclesCivSupply");
if (_truckTypes isEqualTo []) then { _truckTypes = FactionGet(reb, "vehiclesCivTruck") };
if (_truckTypes isEqualTo []) then { _truckTypes = ["C_Van_01_box_F"] };
private _truckType = selectRandom _truckTypes;
private _truck = createVehicle [_truckType, markerPos "Synd_HQ" vectorAdd [0, 0, -1000], [], 0, "CAN_COLLIDE"];
_truck enableSimulation false;
call {
    private _testDir = random 360;
    private _pos = [markerPos "Synd_HQ", _truck, _testDir, 0, 50, 50] call A3A_fnc_findEmptyPosCar;
    if (_pos isEqualTo []) then { _pos = markerPos "Synd_HQ" findEmptyPosition [1, 50, _truckType] };
    isNil {
        _truck setPosATL _pos;
        _truck setDir _testDir;
        _truck allowDamage false;
        _truck enableSimulation true;
    };
    _truck spawn { sleep 3; _this allowDamage true };
};
{ _x reveal _truck } forEach (allPlayers - entities "HeadlessClient_F");
[_truck, teamPlayer] call A3A_fnc_AIVEHinit;
_truck lock 2;
_truck setVariable ["A3A_buyIntelCost", BRIBE_COST, true];
_truck setVariable ["A3A_buyIntelMoney", 0, true];
_truck setVariable ["A3A_buyIntelOpen", true, true];        // takes deposits while the task runs
_task set ["_truck", _truck];

private _addTruckAction = {
    params ["_truck"];
    _truck addAction [localize "STR_A3A_Tasks_LOG_BuyIntel_loadAction", {
        A3A_GUI_buyIntelTruck = _this # 0;
        createDialog "A3A_BuyIntelDialog";
    }, nil, 1.5, true, true, "", "alive _target and isNull objectParent _this and (_target getVariable ['A3A_buyIntelOpen', false])
        and (_target getVariable ['A3A_buyIntelMoney', 0]) < (_target getVariable ['A3A_buyIntelCost', 1000])", 6];
};
[_truck, _addTruckAction] remoteExec ["call", 0, _truck];

// Task
private _taskId = "LOG" + str A3A_taskCount;
private _displayTime = [DURATION / 60] call FUNC(minutesFromNow);
private _taskDesc = format [localize "STR_A3A_Tasks_LOG_BuyIntel_desc", _faction get "name", _task get "_cityName", BRIBE_COST, TRUCK_RANGE, _displayTime];
[[teamPlayer, civilian], _taskId, [_taskDesc, _task get "_hintTitle", ""], _officerPos, false, 0, true, "meet", true] call BIS_fnc_taskCreate;
[_taskId, "LOG", "CREATED"] remoteExecCall ["A3A_fnc_taskUpdate", 2];
_task set ["_taskId", _taskId];

_task set ["state", "s_waiting"];
_task set ["interval", 2];

Trace_1("Initial data: %1", _task);


//////////////////////
// Helper functions //
//////////////////////

// The officer gets in his car and drives back to his outpost (on foot if the car is gone), then despawns
_task set ["_fnc_driveOff", {
    params ["_task"];
    private _officer = _task get "_officer";
    private _group = _task get "_group";
    private _car = _task get "_car";
    if (!alive _officer) exitWith {};

    // Outpost fell: the nearest outpost or airbase of his side instead
    private _side = _task get "_side";
    private _destMrk = _task get "_destMrk";
    if (sidesX getVariable _destMrk != _side) then {
        private _alternatives = (outposts + airportsX) select { sidesX getVariable _x == _side };
        if (_alternatives isEqualTo []) exitWith {};
        _destMrk = [_alternatives, _officer] call BIS_fnc_nearestPosition;
    };

    _officer setVariable ["A3A_buyIntelReady", false, true];
    _officer enableAI "PATH";
    _group setBehaviourStrong "CARELESS";
    _group setSpeedMode "FULL";
    { deleteWaypoint _x } forEachReversed (waypoints _group);
    private _firstWp = [];
    if (alive _car and { canMove _car and isNull driver _car }) then {
        _officer assignAsDriver _car;
        [_officer] orderGetIn true;
        _firstWp = _group addWaypoint [getPosATL _car, 0];
        _firstWp setWaypointType "GETIN";
        _firstWp waypointAttachVehicle _car;
    };
    private _wp = _group addWaypoint [markerPos _destMrk, 50];
    _wp setWaypointType "MOVE";
    _group setCurrentWaypoint ([_firstWp, _wp] select (_firstWp isEqualTo []));
}];

// He saw someone coming at him openly: stand and fight
_task set ["_fnc_fight", {
    params ["_task"];
    private _officer = _task get "_officer";
    private _group = _task get "_group";
    _officer setVariable ["A3A_buyIntelReady", false, true];
    _officer enableAI "PATH";
    _group setCombatMode "RED";
    _group setBehaviourStrong "COMBAT";
}];

// Spawned on the server when the task fails: bribe money still in the truck goes back to the faction at HQ
_task set ["_fnc_returnMoney", {
    params ["_truck", "_hintTitle"];
    while { alive _truck and { _truck getVariable ["A3A_buyIntelMoney", 0] > 0 } } do {
        if (_truck distance2d markerPos "Synd_HQ" < 50) exitWith {
            private _money = _truck getVariable ["A3A_buyIntelMoney", 0];
            _truck setVariable ["A3A_buyIntelMoney", 0, true];
            [0, _money] remoteExec ["A3A_fnc_resourcesFIA", 2];
            Info_1("Buying intel: %1 of unused bribe money returned to the faction", _money);
            [_hintTitle, format [localize "STR_A3A_Tasks_LOG_BuyIntel_refunded", _money], getPosATL _truck, 300] call FUNC(hintNear);
        };
        sleep 5;
    };
}];


/////////////////////
// State functions //
/////////////////////

_task set ["s_waiting", {
    private _officer = _this get "_officer";
    private _truck = _this get "_truck";
    private _officerPos = getPosATL _officer;

    if (!alive _officer) exitWith {
        [_this get "_hintTitle", localize "STR_A3A_Tasks_LOG_BuyIntel_dead", _officerPos, 1000] call FUNC(hintNear);
        _this set ["state", "s_failure"]; false;
    };

    if (!alive _truck) exitWith {
        [_this get "_hintTitle", localize "STR_A3A_Tasks_LOG_BuyIntel_truckLost", _officerPos, 1000] call FUNC(hintNear);
        [_this] call (_this get "_fnc_driveOff");
        _this set ["state", "s_failure"]; false;
    };

    // Rebels who are not undercover, in town or close to the officer, that his side knows about
    private _side = _this get "_side";
    private _cityRadius = _this get "_cityRadius";
    private _exposed = units teamPlayer select {
        alive _x and !captive _x
        and { _x inArea [markerPos (_this get "_city"), _cityRadius, _cityRadius, 0, false] or _x distance2d _officer < 300 }
        and { _side knowsAbout _x > 1.4 or _officer knowsAbout _x > 1.4 }
    };
    // Close enough for him to see who is coming, or shot at: he fights. Otherwise he leaves before they get to him.
    private _threat = _officer getVariable ["A3A_unitHit", false] or { _exposed findIf { _x distance2d _officer < FIGHT_RANGE } != -1 };
    if (_threat) exitWith {
        [_this get "_hintTitle", localize "STR_A3A_Tasks_LOG_BuyIntel_fight", _officerPos, 1000] call FUNC(hintNear);
        [_this] call (_this get "_fnc_fight");
        _this set ["state", "s_failure"]; false;
    };
    if (_exposed isNotEqualTo []) exitWith {
        [_this get "_hintTitle", format [localize "STR_A3A_Tasks_LOG_BuyIntel_spotted", _this get "_cityName"], _officerPos, 1000] call FUNC(hintNear);
        [_this] call (_this get "_fnc_driveOff");
        _this set ["state", "s_failure"]; false;
    };

    // Out of time. He waits up to 10 more minutes while rebels are at the meeting
    private _endTime = _this get "_endTime";
    if (time > _endTime and { time > _endTime + 10*60 or call A3A_fnc_playableUnits inAreaArray [_officerPos, 300, 300] isEqualTo [] }) exitWith {
        [_this get "_hintTitle", localize "STR_A3A_Tasks_LOG_BuyIntel_timeout", _officerPos, 1000] call FUNC(hintNear);
        [_this] call (_this get "_fnc_driveOff");
        _this set ["state", "s_failure"]; false;
    };

    // Bribe handed over
    if (!isNil { _officer getVariable "A3A_buyIntelPaidBy" }) exitWith {
        _this set ["state", "s_success"]; false;
    };

    // The officer takes the money once the full truck is parked next to him
    private _ready = _truck getVariable ["A3A_buyIntelMoney", 0] >= BRIBE_COST
        and { _truck distance2d _officer <= TRUCK_RANGE and vectorMagnitude velocity _truck < 1 };
    if (_ready isNotEqualTo (_officer getVariable ["A3A_buyIntelReady", false])) then {
        _officer setVariable ["A3A_buyIntelReady", _ready, true];
    };
    false;
}];

_task set ["s_success", {
    private _officer = _this get "_officer";
    private _truck = _this get "_truck";
    private _payer = _officer getVariable "A3A_buyIntelPaidBy";
    Info_2("Buying intel: bribe in %1 handed over by %2", _this get "_city", name _payer);

    _truck setVariable ["A3A_buyIntelOpen", false, true];
    _truck setVariable ["A3A_buyIntelMoney", 0, true];

    ["Large", _this get "_side"] call A3A_fnc_selectIntel;

    [_this get "_hintTitle", localize "STR_A3A_Tasks_LOG_BuyIntel_success", getPosATL _officer, 500] call FUNC(hintNear);
    [_this get "_taskId", "SUCCEEDED", getPosATL _officer, 500] call FUNC(taskNotifyNear);
    [_this get "_taskId", "LOG", "SUCCEEDED"] call A3A_fnc_taskSetState;

    [_this] call (_this get "_fnc_driveOff");
    _this set ["state", "s_cleanup"]; false;
}];

_task set ["s_failure", {
    private _truck = _this get "_truck";
    [_this get "_taskId", "LOG", "FAILED"] call A3A_fnc_taskSetState;

    if (alive _truck) then {
        _truck setVariable ["A3A_buyIntelOpen", false, true];
        [_truck, 0] remoteExec ["lock", _truck];
        private _money = _truck getVariable ["A3A_buyIntelMoney", 0];
        if (_money > 0) then {
            [_this get "_hintTitle", format [localize "STR_A3A_Tasks_LOG_BuyIntel_refundHint", _money], getPosATL _truck, 1000] call FUNC(hintNear);
            [_truck, _this get "_hintTitle"] spawn (_this get "_fnc_returnMoney");
        };
    };
    _this set ["state", "s_cleanup"]; false;
}];

_task set ["s_cleanup", {
    private _officer = _this get "_officer";
    if (alive _officer) then { _officer setVariable ["A3A_buyIntelReady", false, true] };
    [_this get "_group"] spawn A3A_fnc_groupDespawner;
    [_this get "_car"] spawn A3A_fnc_VEHdespawner;
    [_this get "_taskId", "LOG", 1200] spawn A3A_fnc_taskDelete;
    true;       // delete the task
}];

_task;
