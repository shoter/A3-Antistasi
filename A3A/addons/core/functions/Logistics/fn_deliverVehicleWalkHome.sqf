/*
Maintainer: Shoter
    Walks a delivery driver on foot to the nearest rebel site and returns him to the HR pool there.
    The driver fights back on the way and stays a spawner, so the walk can be intercepted too.
    The target is picked again when the site is lost or the HQ starts moving.
    A driver who has not arrived by the deadline is taken home as soon as no player is near him
    (stuck AI, long fights); a dead driver's HR is lost.

Arguments:
    <STRING> Requesting player UID, for the hints
    <OBJECT> Driver
    <GROUP> Driver's group

Return Value:
    <nil>

Scope: Server
Environment: Scheduled
Public: No
Dependencies:
    A3A_deliverVehicleHR, A3A_fnc_resourcesFIA

Example:
    [_uid, _driver, _crewGroup] call A3A_fnc_deliverVehicleWalkHome;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

// Within this distance of the site centre (or inside its area) the driver is home
#define WALK_ARRIVAL_DIST 60
// Walking pace used for the deadline, metres per second, plus a flat allowance for fights and detours
#define WALK_PACE 1
#define WALK_ALLOWANCE 600
// No player within this distance lets an overdue driver vanish home
#define WALK_UNSEEN_DIST 1000

params [["_uid", "", [""]], ["_driver", objNull, [objNull]], ["_crewGroup", grpNull, [grpNull]]];
if (!alive _driver) exitWith {};

private _fnc_hint = {
    params ["_key", ["_args", []]];
    private _index = allPlayers findIf { getPlayerUID _x == _uid };
    if (_index == -1) exitWith {};
    ["STR_A3A_fn_logistics_deliverVehicle_" + _key, _args] remoteExecCall ["A3A_fnc_deliverVehicleHint", allPlayers # _index];
};
private _fnc_homeSite = {
    private _sites = (outposts + airportsX + seaports + factories + resourcesX) select { sidesX getVariable [_x, sideUnknown] == teamPlayer };
    if !(missionNamespace getVariable ["A3A_petrosMoving", false]) then { _sites pushBack "Synd_HQ" };
    if (_sites isEqualTo []) exitWith { "" };
    [_sites, getPosATL _driver] call BIS_fnc_nearestPosition
};
private _fnc_siteOK = {
    params ["_site"];
    if (_site == "") exitWith { false };
    if (_site == "Synd_HQ") exitWith { !(missionNamespace getVariable ["A3A_petrosMoving", false]) };
    sidesX getVariable [_site, sideUnknown] == teamPlayer
};
private _fnc_down = { _driver getVariable ["incapacitated", false] };

// On foot and ready to defend himself
{ _driver enableAI _x } forEach ["TARGET", "AUTOTARGET", "AUTOCOMBAT"];
_crewGroup setBehaviourStrong "AWARE";
_crewGroup setCombatMode "YELLOW";
_crewGroup setSpeedMode "FULL";
{ deleteWaypoint _x } forEachReversed waypoints _crewGroup;

private _home = call _fnc_homeSite;
private _homePos = markerPos _home;
private _homeName = [_home] call A3A_fnc_localizar;
if (_home != "") then { _driver doMove _homePos };
["walking", [_homeName]] call _fnc_hint;

private _deadline = time + WALK_ALLOWANCE + (_driver distance2D _homePos) / WALK_PACE;
private _result = "";
while { _result == "" } do {
    sleep 5;
    if (!alive _driver) then { _result = "lost"; continue };
    if (call _fnc_down) then { continue };          // bleeding out or waiting for a medic, the deadline keeps running

    // Lost site or moving HQ: pick the nearest one again
    if !([_home] call _fnc_siteOK) then {
        _home = call _fnc_homeSite;
        if (_home == "") then { continue };
        _homePos = markerPos _home;
        _homeName = [_home] call A3A_fnc_localizar;
        _driver doMove _homePos;
    };

    if (_driver distance2D _homePos < WALK_ARRIVAL_DIST || { _driver inArea _home }) then { _result = "home"; continue };
    if (time > _deadline && { allPlayers findIf { _x distance2D _driver < WALK_UNSEEN_DIST } == -1 }) then { _result = "home"; continue };

    // Fights and blocked paths leave the unit idle, send him on again
    if (unitReady _driver) then { _driver doMove _homePos };
};

if (_result == "home") then {
    deleteVehicle _driver;
    [A3A_deliverVehicleHR, 0, true] spawn A3A_fnc_resourcesFIA;
    ["returned", [_homeName, A3A_deliverVehicleHR]] call _fnc_hint;
} else {
    ["driver_lost", [_homeName]] call _fnc_hint;
};
if (!isNull _crewGroup) then {
    _crewGroup setVariable ["A3A_AIScriptHandle", nil];
    if (units _crewGroup isEqualTo []) then { deleteGroup _crewGroup };
};
Info_3("Vehicle delivery driver for %1 walked to %2: %3", _uid, _home, _result);
