/*
Maintainer: Shoter
    Loot crate delivery by pickup: spawns a civilian car with a civilian driver at HQ, drives it along the
    roads to the drop position, unloads a loot crate there and drives back to HQ, where it despawns.
    Car and driver are on the civilian side, so enemies leave them alone.
    Ends by calling A3A_fnc_lootDeliveryFinish exactly once.

Arguments:
    <ARRAY> Delivery order, see A3A_fnc_lootDeliveryRequest
    <STRING> Car classname
    <POSITION> Drop position

Return Value:
    <nil>

Scope: Server
Environment: Scheduled, spawned
Public: No
Dependencies:
    A3A_fnc_findHQVehicleSlot, A3A_fnc_findPath, A3A_fnc_vehicleConvoyTravel, A3A_fnc_lootDeliveryMarker,
    A3A_fnc_lootDeliveryCrate, A3A_fnc_lootDeliveryFinish

Example:
    [_order, _class, _pos] spawn A3A_fnc_lootDeliveryPickup;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

// Speed limit on the road in km/h
#define PICKUP_MAX_SPEED 70
// Road search radius around the drop position for the final route node
#define PICKUP_ROAD_SEARCH 150
// Distance from the last route node that counts as arrived, vehicleConvoyTravel stops within 100 m
#define PICKUP_ARRIVAL_DIST 120
// Seconds given to the last stretch from the end of the route to the drop position
#define PICKUP_APPROACH_TIME 60
// Seconds spent unloading the crate
#define PICKUP_UNLOAD_TIME 5

params ["_order", "_class", "_dropPos"];
_order params ["_id", "", "", "", "", "", "", "_dropMarker"];

///////////
// Spawn //
///////////

private _veh = createVehicle [_class, [0, 0, -1000], [], 0, "CAN_COLLIDE"];
if (isNull _veh) exitWith {
    Error_1("Loot delivery could not spawn %1", _class);
    [_order, objNull, grpNull, "", false, false, true] call A3A_fnc_lootDeliveryFinish;
};
_veh enableSimulation false;

// Road slot facing out of HQ, same placement as bought High Command vehicles
([_veh] call A3A_fnc_findHQVehicleSlot) params [["_spawnPos", []], ["_spawnDir", []]];
if (_spawnPos isEqualTo []) then {
    private _searchCenter = markerPos respawnTeamPlayer getPos [50 + random 50, random 360];
    _spawnPos = _searchCenter findEmptyPosition [0, 50, _class];
    if (_spawnPos isEqualTo []) then { _spawnPos = _searchCenter };
    _veh setVehiclePosition [_spawnPos, [], 0, "NONE"];
    _veh setDir random 360;
} else {
    isNil {
        _veh setVehiclePosition [_spawnPos, [], 0, "CAN_COLLIDE"];
        _veh setVectorDir _spawnDir;
    };
};
_veh enableSimulation true;
[_veh, true, true, true, true] call A3A_fnc_clearVehicleCargo;
[_veh, civilian] call A3A_fnc_AIVEHinit;
_veh lock 2;                                    // not a free car for whoever meets it on the road
_veh setFuel 1;

private _group = createGroup [civilian, true];
private _driver = [_group, FactionGet(civ,"unitMan"), getPosATL _veh, [], 0, "NONE"] call A3A_fnc_createUnit;
_driver assignAsDriver _veh;
_driver moveInDriver _veh;
_group addVehicle _veh;
{ _driver disableAI _x } forEach ["TARGET", "AUTOTARGET", "AUTOCOMBAT"];
_driver allowFleeing 0;
_driver setSkill 0.5;
_group setBehaviourStrong "CARELESS";
_driver action ["engineOn", _veh];

private _vehMarker = [_order, _veh] call A3A_fnc_lootDeliveryMarker;
Info_3("Loot delivery %1: %2 spawned at %3", _id, _class, _spawnPos);

/////////////
// Helpers //
/////////////

private _fnc_vehOK = { !isNull _veh && { alive _veh } && { canMove _veh } && { alive driver _veh } };

// Drive along a route, returns true when the car got within reach of the last node
private _fnc_travel = {
    params ["_route"];
    private _destination = _route # (count _route - 1);
    private _length = 0;
    for "_i" from 1 to (count _route - 1) do { _length = _length + ((_route # (_i - 1)) distance2D (_route # _i)) };
    private _deadline = time + 120 + _length / 5;           // generous: 18 km/h average

    private _convoy = [_veh];
    private _travel = [_veh, _route, _convoy, PICKUP_MAX_SPEED, false] spawn A3A_fnc_vehicleConvoyTravel;
    waitUntil { sleep 2; scriptDone _travel || { !(call _fnc_vehOK) } || { time > _deadline } };
    if (_veh in _convoy) then { _convoy deleteAt (_convoy find _veh) };      // stops the travel script if it is still running
    (call _fnc_vehOK) && { _veh distance2D _destination < PICKUP_ARRIVAL_DIST }
};

// Last stretch beyond the route, the convoy travel stops up to 100 m short. Best effort, never fails the run.
private _fnc_approach = {
    params ["_target", "_radius"];
    { deleteWaypoint _x } forEachReversed waypoints _group;
    private _wp = _group addWaypoint [_target, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointBehaviour "CARELESS";
    _wp setWaypointCompletionRadius 10;
    _group setCurrentWaypoint _wp;
    _veh limitSpeed 30;
    private _end = time + PICKUP_APPROACH_TIME;
    waitUntil { sleep 1; _veh distance2D _target < _radius || { !(call _fnc_vehOK) } || { time > _end } };
    { deleteWaypoint _x } forEachReversed waypoints _group;
};

///////////
// Route //
///////////

private _startPos = getPosATL _veh;
private _endPos = _dropPos;
private _roads = _dropPos nearRoads PICKUP_ROAD_SEARCH;
if (_roads isNotEqualTo []) then {
    _roads = _roads apply { [_x distance2D _dropPos, _x] };
    _roads sort true;
    _endPos = getPosATL (_roads # 0 # 1);
};
_dropMarker setMarkerPos _endPos;

private _route = [_startPos, _endPos] call A3A_fnc_findPath;
_route = _route apply { _x select 0 };          // reduce to position array
if (_route isEqualTo []) then { _route = [_startPos, _endPos] };

//////////////
// Outbound //
//////////////

private _dropped = false;
private _home = false;

if ([_route] call _fnc_travel) then {
    [_endPos, 15] call _fnc_approach;
    if (call _fnc_vehOK) then {
        _veh forceSpeed 0;
        waitUntil { sleep 1; abs speed _veh < 1 || { !(call _fnc_vehOK) } };
        sleep PICKUP_UNLOAD_TIME;
    };
    if (!isNull _veh && { alive _veh }) then {
        // Behind the tailgate, or wherever there is room near it
        private _cratePos = _veh modelToWorld [0, -6, 0];
        _cratePos set [2, 0];
        private _emptyPos = _cratePos findEmptyPosition [0, 15, FactionGet(reb,"surrenderCrate")];
        if (_emptyPos isNotEqualTo []) then { _cratePos = _emptyPos };
        [_order, _cratePos] call A3A_fnc_lootDeliveryCrate;
        _dropped = true;
    };
};

////////////
// Return //
////////////

if (_dropped && { call _fnc_vehOK }) then {
    sleep PICKUP_UNLOAD_TIME;
    _veh forceSpeed -1;
    _veh limitSpeed PICKUP_MAX_SPEED;
    reverse _route;
    _home = [_route] call _fnc_travel;
};

[_order, _veh, _group, _vehMarker, _dropped, _home] call A3A_fnc_lootDeliveryFinish;
