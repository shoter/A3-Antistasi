/*
Maintainer: Shoter
    Commander request to send a garaged ammo truck to rearm a rebel garrison.
    Validates the site, the truck and the HR, takes the truck out of the garage, charges 1 HR for the driver,
    spawns the truck at HQ and starts the run (A3A_fnc_garrisonResupplyRun). Rejections are answered with a hint.

Arguments:
    <OBJECT> Requesting player, must be the commander
    <STRING> Marker of the garrison to resupply
    <NUMBER> Garage vehicle UID of the ammo truck (support category)
    <NUMBER> Client id to answer to (clientOwner of the requester)

Return Value:
    <nil>

Scope: Server
Environment: Scheduled (the HQ slot search is slow)
Public: No
Dependencies:
    HR_GRG_Vehicles, HR_GRG_Users, A3A_garrison, A3A_garrisonResupplyActive,
    A3A_fnc_garrisonResupplyTruckPoints, A3A_fnc_garrisonResupplySpawn, A3A_fnc_garrisonResupplyRun, A3A_fnc_airTaxiGarageSync

Example:
    [player, "outpost_1", _vehUID, clientOwner] remoteExecCall ["A3A_fnc_garrisonResupplyRequest", 2];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

#define RESUPPLY_HR_COST 1
// Average ground speed used for the ETA hint, metres per second along the road
#define RESUPPLY_ETA_SPEED 8

params [["_player", objNull, [objNull]], ["_marker", "", [""]], ["_vehUID", -1, [0]], ["_client", -1, [0]]];
if (!isServer) exitWith { Error("Called on a client, server only") };
if (isNull _player || _client < 0) exitWith {};
if (!canSuspend) exitWith { _this spawn A3A_fnc_garrisonResupplyRequest };
if (isNil "HR_GRG_Vehicles") then { [] call HR_GRG_fnc_initServer };

private _fnc_reject = {
    params ["_key", ["_args", []]];
    Info_3("Garrison resupply request by %1 rejected: %2 %3", name _player, _key, _args);
    ["STR_A3A_fn_logistics_resupply_blk_" + _key, _args] remoteExecCall ["A3A_fnc_garrisonResupplyHint", _client];
};

// Requester and site
if (_player != theBoss) exitWith { ["not_commander"] call _fnc_reject };
private _badSite = _marker == "" || { !(_marker in A3A_garrison) } || { _marker in citiesX } || { _marker == "Synd_HQ" }
    || { sidesX getVariable [_marker, sideUnknown] != teamPlayer };
if (_badSite) exitWith { ["bad_site"] call _fnc_reject };
if (_marker in A3A_garrisonResupplyActive) exitWith { ["active"] call _fnc_reject };
if ([markerPos _marker] call A3A_fnc_enemyNearCheck) exitWith { ["under_attack"] call _fnc_reject };
if (server getVariable ["hr", 0] < RESUPPLY_HR_COST) exitWith { ["no_hr"] call _fnc_reject };

// Something to rearm: any armed vehicle of the site below full
private _info = [_marker, false] call A3A_fnc_garrisonServer_ammoInfo;
if (_info findIf { (_x # 2) < 0.999 } == -1) exitWith { ["nothing_to_do"] call _fnc_reject };

// Garage entry
private _entry = (HR_GRG_Vehicles # 6) getOrDefault [_vehUID, []];      // support category, see garage/Core/fn_getCatIndex.sqf
private _points = [_entry, getPlayerUID _player, _player call HR_GRG_canOverrideLock] call A3A_fnc_garrisonResupplyTruckPoints;
if (_points <= 0) exitWith { ["no_truck"] call _fnc_reject };
_entry params ["_dispName", "_class"];

// Take the truck out of the garage, on the server and on every open garage dialog
_entry = +_entry;
private _recipients = +HR_GRG_Users;
_recipients pushBackUnique 2;
["remove", _vehUID, [], -1, 6] remoteExecCall ["A3A_fnc_airTaxiGarageSync", _recipients];
[-RESUPPLY_HR_COST, 0, true] spawn A3A_fnc_resourcesFIA;

// Spawn and drive
([_class, _entry, _marker] call A3A_fnc_garrisonResupplySpawn) params ["_truck", "_crewGroup"];
if (isNull _truck || { !canMove _truck }) exitWith {
    [_marker, _truck, _crewGroup, _vehUID, _entry, 0, 0, RESUPPLY_HR_COST, "no_spawn"] call A3A_fnc_garrisonResupplyFinish;
    ["no_spawn"] call _fnc_reject;
};

private _script = [_marker, _truck, _crewGroup, _vehUID, _entry, RESUPPLY_HR_COST] spawn A3A_fnc_garrisonResupplyRun;
A3A_garrisonResupplyActive set [_marker, _script];

private _eta = ((markerPos respawnTeamPlayer) distance2D (markerPos _marker)) / RESUPPLY_ETA_SPEED;
private _etaString = [[_eta] call A3A_fnc_secondsToTimeSpan, 0, 0, false, 2] call A3A_fnc_timeSpan_format;
["STR_A3A_fn_logistics_resupply_requested", [_dispName, [_marker] call A3A_fnc_localizar, _etaString, round _points]] remoteExecCall ["A3A_fnc_garrisonResupplyHint", _client];
Info_4("Garrison resupply of %1 requested by %2 with %3 (garage UID %4)", _marker, name _player, _dispName, _vehUID);
