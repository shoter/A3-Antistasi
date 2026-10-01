/*
Maintainer: Shoter
    Server entry point for a vehicle delivery request from the Battle Command menu.
    Validates the player, the origin, the destination and the garage entry, takes the vehicle out
    of the garage, takes 1 HR for the driver, spawns the vehicle at the origin and starts the drive.
    Every rejection is reported back to the client as a hint.

Arguments:
    <OBJECT> Requesting player
    <NUMBER> Garage category index of the vehicle (0, 1, 2 or 6, see garage/Core/fn_getCatIndex.sqf)
    <NUMBER> Garage vehicle UID
    <STRING> Origin site marker, see A3A_fnc_deliverVehicleOrigins
    <POSITION> Destination position, anywhere on land
    <NUMBER> Client id of the requester (clientOwner), used for the reply

Return Value:
    <nil>

Scope: Server
Environment: Any, respawns itself scheduled
Public: No
Dependencies:
    HR_GRG_Vehicles, HR_GRG_Users, A3A_deliverVehicleActive, A3A_deliverVehicleHR

Example:
    [player, 1, _vehUID, "outpost_3", getPosATL player, clientOwner] remoteExecCall ["A3A_fnc_deliverVehicleRequest", 2];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [
    ["_player", objNull, [objNull]],
    ["_catIndex", -1, [0]],
    ["_vehUID", -1, [0]],
    ["_origin", "", [""]],
    ["_destPos", [], [[]]],
    ["_client", -1, [0]]
];
if (!isServer) exitWith { Error("Called on a client, server only") };
if (isNull _player || _client < 0) exitWith {};
if (!canSuspend) exitWith { _this spawn A3A_fnc_deliverVehicleRequest };
if (isNil "HR_GRG_Vehicles") then { [] call HR_GRG_fnc_initServer };

private _fnc_reject = {
    params ["_key", ["_args", []]];
    Info_3("Vehicle delivery request by %1 rejected: %2 %3", name _player, _key, _args);
    ["STR_A3A_fn_logistics_deliverVehicle_blk_" + _key, _args] remoteExecCall ["A3A_fnc_deliverVehicleHint", _client];
};

// Player, origin and destination
private _uid = getPlayerUID _player;
if (_destPos isEqualTo []) exitWith { ["off_map"] call _fnc_reject };
private _blockers = [_player, _origin, _destPos] call A3A_fnc_deliverVehicleCanRequest;
if (_blockers isNotEqualTo []) exitWith { [_blockers # 0] call _fnc_reject };
if (_uid in A3A_deliverVehicleActive) exitWith { ["active"] call _fnc_reject };
if (server getVariable ["hr", 0] < A3A_deliverVehicleHR) exitWith { ["no_hr"] call _fnc_reject };

// Garage entry
if !(_catIndex in [0, 1, 2, 6]) exitWith { ["no_vehicle"] call _fnc_reject };
private _entry = (HR_GRG_Vehicles # _catIndex) getOrDefault [_vehUID, []];
private _entryCheck = [_entry] call A3A_fnc_deliverVehicleEntryCheck;
if (_entryCheck != "") exitWith { [_entryCheck] call _fnc_reject };
_entry params ["_dispName", "_class", "_lockUID"];
if (!(_lockUID in ["", _uid]) && { !(_player call HR_GRG_canOverrideLock) }) exitWith { ["no_vehicle"] call _fnc_reject };

// Take the vehicle out of the garage, on the server and on every open garage dialog
_destPos = [_destPos # 0, _destPos # 1, 0];
_entry = +_entry;
private _sourceIndex = if (isNil "HR_GRG_Sources") then { -1 } else { HR_GRG_Sources findIf { _vehUID in _x } };     // ammo, fuel or repair source registry, for a refund
private _recipients = +HR_GRG_Users;
_recipients pushBackUnique 2;
["remove", _vehUID, [], -1, _catIndex] remoteExecCall ["A3A_fnc_airTaxiGarageSync", _recipients];
[-A3A_deliverVehicleHR, 0, true] spawn A3A_fnc_resourcesFIA;

// Spawn and drive
([_class, _entry, _origin, _destPos, _player] call A3A_fnc_deliverVehicleSpawn) params ["_veh", "_crewGroup"];
if (isNull _veh || { !canMove _veh }) exitWith {
    if (!isNull _veh) then {
        { deleteVehicle _x } forEach units _crewGroup;
        deleteVehicle _veh;
    };
    if (!isNull _crewGroup) then { deleteGroup _crewGroup };
    ["insert", _vehUID, _entry, _sourceIndex, _catIndex] remoteExecCall ["A3A_fnc_airTaxiGarageSync", _recipients];
    [A3A_deliverVehicleHR, 0, true] spawn A3A_fnc_resourcesFIA;
    ["no_spawn"] call _fnc_reject;
};

_player setVariable ["A3A_deliverVehicle", _veh, true];
private _script = [_player, _uid, _veh, _crewGroup, _origin, _destPos, _vehUID, _entry] spawn A3A_fnc_deliverVehicleRun;
A3A_deliverVehicleActive set [_uid, _script];

private _eta = [markerPos _origin, _destPos] call A3A_fnc_deliverVehicleEta;
private _etaString = [[_eta] call A3A_fnc_secondsToTimeSpan, 0, 0, false, 2] call A3A_fnc_timeSpan_format;
["STR_A3A_fn_logistics_deliverVehicle_requested", [_dispName, [_origin] call A3A_fnc_localizar, _etaString]] remoteExecCall ["A3A_fnc_deliverVehicleHint", _client];
Info_5("Vehicle delivery of %1 (garage UID %2) requested by %3 from %4 to %5", _dispName, _vehUID, name _player, _origin, mapGridPosition _destPos);
