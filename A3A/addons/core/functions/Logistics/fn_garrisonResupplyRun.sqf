/*
Maintainer: Shoter
    Drives a garrison resupply truck from HQ to the site, rearms the garrison there, and drives it back.
    The truck follows the road network like an enemy convoy and shows as a friendly vehicle marker on the map.
    Ends by calling A3A_fnc_garrisonResupplyFinish exactly once.

    Outcomes reported to A3A_fnc_garrisonResupplyFinish: completed, stuck (never reached the site),
    stranded (rearmed the site but could not get home), destroyed.

Arguments:
    <STRING> Marker of the garrison to resupply
    <OBJECT> Ammo truck
    <GROUP> Crew group (driver)
    <NUMBER> Garage vehicle UID
    <ARRAY> Garage entry copied at request time
    <NUMBER> HR paid for the driver

Return Value:
    <nil>

Scope: Server
Environment: Scheduled, spawned
Public: No
Dependencies:
    A3A_fnc_findPath, A3A_fnc_vehicleConvoyTravel, A3A_fnc_vehicleMarkers, A3A_fnc_garrisonResupplyApply, A3A_fnc_garrisonResupplyFinish

Example:
    [_marker, _truck, _crewGroup, _vehUID, _entry, 1] spawn A3A_fnc_garrisonResupplyRun;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

// Convoy speed limit in km/h, as the enemy convoys use
#define RESUPPLY_MAX_SPEED 40
// Distance from the last route node that counts as arrived, vehicleConvoyTravel stops within 100 m
#define RESUPPLY_ARRIVAL_DIST 120
// Seconds spent at the site handing over the ammunition
#define RESUPPLY_UNLOAD_TIME 20
// Road search radius around the marker for the final route node
#define RESUPPLY_ROAD_SEARCH 150

params ["_marker", "_truck", "_crewGroup", "_vehUID", "_entry", "_hr"];

_crewGroup setVariable ["A3A_AIScriptHandle", _thisScript];
private _siteName = [_marker] call A3A_fnc_localizar;
private _outcome = "";
private _spent = 0;
private _serviced = 0;

/////////////
// Helpers //
/////////////

private _fnc_truckOK = { !isNull _truck && { alive _truck } && { canMove _truck } && { alive driver _truck } };
private _fnc_failReason = { if (isNull _truck || { !alive _truck }) then { "destroyed" } else { _this } };
private _fnc_hint = {
    params ["_key", ["_args", []]];
    if (isNull theBoss || { !isPlayer theBoss }) exitWith {};
    ["STR_A3A_fn_logistics_resupply_" + _key, _args] remoteExecCall ["A3A_fnc_garrisonResupplyHint", theBoss];
};

// Drive the truck along a route, returns true when it got within reach of the last node
private _fnc_travel = {
    params ["_route"];
    private _destination = _route # (count _route - 1);
    private _length = 0;
    for "_i" from 1 to (count _route - 1) do { _length = _length + ((_route # (_i - 1)) distance2D (_route # _i)) };
    private _deadline = time + 120 + _length / 4;          // generous: half of the 30 km/h convoy pace

    private _convoy = [_truck];
    private _travel = [_truck, _route, _convoy, RESUPPLY_MAX_SPEED, false] spawn A3A_fnc_vehicleConvoyTravel;
    waitUntil { sleep 2; scriptDone _travel || { !(call _fnc_truckOK) } || { time > _deadline } };
    if (_truck in _convoy) then { _convoy deleteAt (_convoy find _truck) };      // stops the travel script if it is still running
    (call _fnc_truckOK) && { _truck distance2D _destination < RESUPPLY_ARRIVAL_DIST }
};

///////////
// Route //
///////////

private _startPos = getPosATL _truck;
private _sitePos = markerPos _marker;

// End on the nearest road so the truck is not sent into the compound buildings
private _roads = _sitePos nearRoads RESUPPLY_ROAD_SEARCH;
if (_roads isNotEqualTo []) then {
    _roads = _roads apply { [_x distance2D _sitePos, _x] };
    _roads sort true;
    _sitePos = getPosATL (_roads # 0 # 1);
};

private _route = [_startPos, _sitePos] call A3A_fnc_findPath;
_route = _route apply { _x select 0 };          // reduce to position array
if (_route isEqualTo []) then { _route = [_startPos, _sitePos] };

// Friendly vehicle marker on every rebel map, updated by A3A_fnc_vehicleMarkers until the truck is gone
_truck setVariable ["revealed", true, true];
[_truck, localize "STR_A3A_fn_logistics_resupply_marker"] remoteExec ["A3A_fnc_vehicleMarkers", [teamPlayer, civilian], _truck];

/////////////
// Outbound //
/////////////

private _arrived = [_route] call _fnc_travel;
if (!_arrived) then { _outcome = "stuck" call _fnc_failReason };

if (_outcome == "") then {
    ["arrived", [_siteName]] call _fnc_hint;
    sleep RESUPPLY_UNLOAD_TIME;
    if !(call _fnc_truckOK) then { _outcome = "stuck" call _fnc_failReason };
};

if (_outcome == "") then {
    ([_marker, _truck] call A3A_fnc_garrisonResupplyApply) params ["_pointsSpent", "_vehiclesServiced"];
    _spent = _pointsSpent;
    _serviced = _vehiclesServiced;
    Info_3("Garrison resupply of %1: %2 ammo points spent on %3 vehicles", _marker, _spent, _serviced);
};

////////////
// Return //
////////////

if (_outcome == "") then {
    reverse _route;
    private _home = [_route] call _fnc_travel;
    _outcome = if (_home) then { "completed" } else { "stranded" call _fnc_failReason };
};

[_marker, _truck, _crewGroup, _vehUID, _entry, _spent, _serviced, _hr, _outcome] call A3A_fnc_garrisonResupplyFinish;
