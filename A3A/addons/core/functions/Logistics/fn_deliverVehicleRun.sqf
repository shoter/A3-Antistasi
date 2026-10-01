/*
Maintainer: Shoter
    Drives a delivered vehicle from its origin site to the destination along the road network,
    leaves it there for the requesting player and sends the driver home on foot.
    The driver is a spawner and drives careless, so enemies along the road can intercept the delivery.
    Ends the delivery with A3A_fnc_deliverVehicleFinish and then walks the driver home with
    A3A_fnc_deliverVehicleWalkHome when he is still alive.

    Outcomes reported to A3A_fnc_deliverVehicleFinish: delivered, stranded, driver_killed, destroyed.

Arguments:
    <OBJECT> Requesting player
    <STRING> Requesting player UID
    <OBJECT> Vehicle
    <GROUP> Crew group
    <STRING> Origin site marker
    <POSITION> Destination position
    <NUMBER> Garage vehicle UID
    <ARRAY> Garage entry copied at request time

Return Value:
    <nil>

Scope: Server
Environment: Scheduled, spawned
Public: No
Dependencies:
    A3A_fnc_findPath, A3A_fnc_vehicleConvoyTravel, A3A_fnc_deliverVehicleFinish, A3A_fnc_deliverVehicleWalkHome

Example:
    [_player, _uid, _veh, _crewGroup, _origin, _destPos, _vehUID, _entry] spawn A3A_fnc_deliverVehicleRun;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

// Speed limit on the road in km/h, a bit quicker than the enemy convoys
#define DELIVERY_MAX_SPEED 50
// Distance from the last route node that counts as arrived, vehicleConvoyTravel stops within 100 m
#define DELIVERY_ARRIVAL_DIST 120
// Road search radius around the destination for the last route node
#define DELIVERY_ROAD_SEARCH 300
// Close enough to the clicked destination to stop the off-road leg
#define DELIVERY_PARK_DIST 25

params ["_player", "_uid", "_veh", "_crewGroup", "_origin", "_destPos", "_vehUID", "_entry"];

_crewGroup setVariable ["A3A_AIScriptHandle", _thisScript];
private _driver = driver _veh;
private _outcome = "";

/////////////
// Helpers //
/////////////

private _fnc_driveOK = {
    alive _veh && { canMove _veh } && { alive _driver } && { vehicle _driver == _veh } && { !(_driver getVariable ["incapacitated", false]) }
};
private _fnc_failReason = {
    switch (true) do {
        case (isNull _veh || { !alive _veh }): { "destroyed" };
        case (!alive _driver || { _driver getVariable ["incapacitated", false] } || { vehicle _driver != _veh }): { "driver_killed" };
        default { "stranded" };
    };
};

// Drive along a route, returns true when the vehicle got within reach of the last node
private _fnc_travel = {
    params ["_route"];
    private _destination = _route # (count _route - 1);
    private _length = 0;
    for "_i" from 1 to (count _route - 1) do { _length = _length + ((_route # (_i - 1)) distance2D (_route # _i)) };
    private _deadline = time + 120 + _length / 4;          // generous: about a third of the speed limit

    private _convoy = [_veh];
    private _travel = [_veh, _route, _convoy, DELIVERY_MAX_SPEED, false] spawn A3A_fnc_vehicleConvoyTravel;
    waitUntil { sleep 2; scriptDone _travel || { !(call _fnc_driveOK) } || { time > _deadline } };
    if (_veh in _convoy) then { _convoy deleteAt (_convoy find _veh) };      // stops the travel script if it is still running
    (call _fnc_driveOK) && { _veh distance2D _destination < DELIVERY_ARRIVAL_DIST }
};

///////////
// Route //
///////////

private _startPos = getPosATL _veh;

// The road leg ends on the road nearest to the destination, the rest is driven off-road
private _roadEnd = _destPos;
private _roads = (_destPos nearRoads DELIVERY_ROAD_SEARCH) apply { [_x distance2D _destPos, _x] };
if (_roads isNotEqualTo []) then {
    _roads sort true;
    _roadEnd = getPosATL (_roads # 0 # 1);
};

private _route = [_startPos, _roadEnd] call A3A_fnc_findPath;
_route = _route apply { _x select 0 };          // reduce to position array
if (_route isEqualTo []) then { _route = [_startPos, _roadEnd] };

// Friendly vehicle marker on every rebel map, updated by A3A_fnc_vehicleMarkers until the delivery is handed over
_veh setVariable ["revealed", true, true];
[_veh, localize "STR_A3A_fn_logistics_deliverVehicle_marker"] remoteExec ["A3A_fnc_vehicleMarkers", [teamPlayer, civilian], _veh];

//////////
// Road //
//////////

if !([_route] call _fnc_travel) then { _outcome = call _fnc_failReason };

//////////////
// Off-road //
//////////////

if (_outcome == "" && { _veh distance2D _destPos > DELIVERY_PARK_DIST }) then {
    { deleteWaypoint _x } forEachReversed waypoints _crewGroup;
    _driver doMove _destPos;
    private _start = time;
    private _deadline = time + 30 + (_veh distance2D _destPos) / 3;
    waitUntil {
        sleep 1;
        _veh distance2D _destPos < DELIVERY_PARK_DIST || { !(call _fnc_driveOK) } || { time > _deadline }
            || { time > _start + 10 && { unitReady _driver } }
    };
    // Gave up off-road (no way through): the vehicle stays where it got to, at the road end at worst
    if !(call _fnc_driveOK) then { _outcome = call _fnc_failReason };
};

if (_outcome == "") then { _outcome = "delivered" };

/////////////
// Park up //
/////////////

if (alive _veh && { alive _driver } && { vehicle _driver == _veh }) then {
    doStop _driver;
    private _stopEnd = time + 10;
    waitUntil { sleep 0.5; abs speed _veh < 1 ||{ time > _stopEnd } || { !alive _veh } };
    _veh engineOn false;
};
if (alive _veh) then {
    _veh lockDriver false;          // the locks are only there to keep players out on the way
    { _veh lockTurret [_x, false] } forEach allTurrets [_veh, false];
};
if (alive _driver && { vehicle _driver != _driver }) then {
    unassignVehicle _driver;
    _crewGroup leaveVehicle _veh;
    _driver action ["GetOut", vehicle _driver];
    private _outEnd = time + 6;
    waitUntil { sleep 0.5; vehicle _driver == _driver || { time > _outEnd } || { !alive _driver } };
    if (alive _driver && { vehicle _driver != _driver }) then { moveOut _driver };
};

[_player, _uid, _veh, _crewGroup, _entry, _destPos, _outcome] call A3A_fnc_deliverVehicleFinish;

////////////////
// Walk home  //
////////////////

// A dead driver's HR is lost, the body is left to the garbage cleaner
if (alive _driver) then { [_uid, _driver, _crewGroup] call A3A_fnc_deliverVehicleWalkHome };
