/*
Maintainer: Shoter
    Terminal cleanup of a garrison resupply run, called exactly once per request.
    Puts the truck back into the garage with its live state when it made it home (or never left),
    refunds the driver's HR when nothing was delivered, writes the chronicle line and tells the commander.

    Outcomes:
        completed       site rearmed, truck back in the garage
        no_spawn        truck could not be placed at HQ, HR refunded, truck back in the garage
        stuck           never reached the site, drove home or was abandoned, HR refunded, truck back in the garage when alive
        stranded        site rearmed but the truck could not get home, it stays in the world as a rebel vehicle
        destroyed       truck lost, garage entry gone

Arguments:
    <STRING> Marker of the garrison
    <OBJECT> Ammo truck (may be objNull or dead)
    <GROUP> Crew group
    <NUMBER> Garage vehicle UID
    <ARRAY> Garage entry copied at request time
    <NUMBER> Ammo points spent
    <NUMBER> Vehicles that received ammunition
    <NUMBER> HR paid for the driver
    <STRING> Outcome

Return Value:
    <nil>

Scope: Server
Environment: Any
Public: No
Dependencies:
    A3A_garrisonResupplyActive, HR_GRG_Users, HR_GRG_fnc_getState, A3A_fnc_airTaxiGarageSync, A3A_fnc_campaignLogAdd

Example:
    [_marker, _truck, _crewGroup, _vehUID, _entry, _spent, _serviced, _hr, "completed"] call A3A_fnc_garrisonResupplyFinish;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [
    ["_marker", "", [""]],
    ["_truck", objNull, [objNull]],
    ["_crewGroup", grpNull, [grpNull]],
    ["_vehUID", -1, [0]],
    ["_entry", [], [[]]],
    ["_spent", 0, [0]],
    ["_serviced", 0, [0]],
    ["_hr", 0, [0]],
    ["_outcome", "completed", [""]]
];
if (!isServer) exitWith { Error("Called on a client, server only") };

A3A_garrisonResupplyActive deleteAt _marker;
private _dispName = _entry param [0, ""];

// Truck back into the garage when it is home in one piece with nobody else aboard, or never left it
private _truckAlive = !isNull _truck && { alive _truck };
private _truckBack = _outcome in ["completed", "no_spawn", "stuck"] && { !_truckAlive || { ((crew _truck) - (units _crewGroup)) isEqualTo [] } };
if (_truckBack && _truckAlive) then {
    _entry set [3, ""];
    _entry set [4, [_truck] call HR_GRG_fnc_getState];         // carries the remaining ammo points
    _entry set [6, [_truck] call BIS_fnc_getVehicleCustomization];
    { deleteVehicle _x } forEach units _crewGroup;              // crew first, so the truck never fires an empty GetOut
    deleteVehicle _truck;
};
if (_truckBack && { _entry isNotEqualTo [] } && { _outcome != "destroyed" }) then {
    private _recipients = +HR_GRG_Users;
    _recipients pushBackUnique 2;
    ["insert", _vehUID, _entry, 0, 6] remoteExecCall ["A3A_fnc_airTaxiGarageSync", _recipients];      // 0: ammo source registry
};

// Stranded or stuck-but-alive trucks stay in the world as ordinary rebel vehicles for the players to recover
if (_truckAlive && !_truckBack) then {
    { deleteVehicle _x } forEach units _crewGroup;
    _truck lockDriver false;
    { _truck lockTurret [_x, false] } forEach allTurrets [_truck, false];
    _truck setVariable ["A3A_garrisonResupply", nil, true];
};
if (!isNull _crewGroup && { units _crewGroup isEqualTo [] }) then { deleteGroup _crewGroup };

// Refund the driver's HR when nothing was delivered
if (_outcome in ["no_spawn", "stuck"] && { _hr > 0 }) then { [_hr, 0, true] spawn A3A_fnc_resourcesFIA };

// Chronicle and commander hint
switch (_outcome) do {
    case ("completed");
    case ("stranded"): {
        ["garrisonResupplied", _marker, [_dispName, round _spent, _serviced]] call A3A_fnc_campaignLogAdd;
    };
    case ("destroyed"): {
        ["garrisonResupplyLost", _marker, [_dispName]] call A3A_fnc_campaignLogAdd;
    };
};
if (!isNull theBoss && { isPlayer theBoss }) then {
    private _key = switch (_outcome) do {
        case ("completed"): { "completed" };
        case ("stranded"): { "stranded" };
        case ("stuck"): { "stuck" };
        case ("destroyed"): { "lost" };
        default { "" };
    };
    if (_key != "") then {
        ["STR_A3A_fn_logistics_resupply_" + _key, [_dispName, [_marker] call A3A_fnc_localizar, round _spent, _serviced]] remoteExecCall ["A3A_fnc_garrisonResupplyHint", theBoss];
    };
};

Info_5("Garrison resupply of %1 finished: %2, truck back %3, %4 points spent on %5 vehicles", _marker, _outcome, _truckBack, _spent, _serviced);
