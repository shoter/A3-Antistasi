/*
Maintainer: Shoter
    Server entry point for an air taxi request from the Battle Command menu.
    Validates the player, the destination and the garage entry, finds the pickup landing zone,
    takes the helicopter out of the garage, charges the fare and the pilot's HR, spawns the
    helicopter and starts the flight script. Every rejection is reported back to the client as a hint.

Arguments:
    <OBJECT> Requesting player
    <NUMBER> Garage vehicle UID of the helicopter
    <STRING> Destination marker
    <NUMBER> Client id of the requester (clientOwner), used for the reply

Return Value:
    <nil>

Scope: Server
Environment: Unscheduled
Public: No
Dependencies:
    HR_GRG_Vehicles, HR_GRG_Users, A3A_airTaxiActive

Example:
    [player, _vehUID, "outpost_1", clientOwner] remoteExecCall ["A3A_fnc_airTaxiRequest", 2];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_player", objNull, [objNull]], ["_vehUID", -1, [0]], ["_destMarker", "", [""]], ["_client", -1, [0]]];
if (!isServer) exitWith { Error("Called on a client, server only") };
if (isNull _player || _client < 0) exitWith {};
if (isNil "HR_GRG_Vehicles") then { [] call HR_GRG_fnc_initServer };

private _fnc_reject = {
    params ["_key", ["_args", []]];
    Info_3("Air taxi request by %1 rejected: %2 %3", name _player, _key, _args);
    ["STR_A3A_fn_logistics_airTaxi_blk_" + _key, _args] remoteExecCall ["A3A_fnc_airTaxiHint", _client];
};

// Player and destination
private _uid = getPlayerUID _player;
private _blockers = [_player, _destMarker] call A3A_fnc_airTaxiCanRequest;
if (_blockers isNotEqualTo []) exitWith { [_blockers # 0] call _fnc_reject };
if (_uid in A3A_airTaxiActive) exitWith { ["active"] call _fnc_reject };

// Garage entry
private _entry = (HR_GRG_Vehicles # 3) getOrDefault [_vehUID, []];      // helicopter category, see garage/CfgDefines.inc
private _entryCheck = [_entry] call A3A_fnc_airTaxiEntryCheck;
if (_entryCheck != "") exitWith { [_entryCheck] call _fnc_reject };
_entry params ["_dispName", "_class", "_lockUID"];
if (!(_lockUID in ["", _uid]) && { !(_player call HR_GRG_canOverrideLock) }) exitWith { ["no_heli"] call _fnc_reject };

// Landing zones: the pickup must exist now, the destination may fall back to a hover drop later
private _pickupPos = getPosATL _player;
private _pickupLZ = [_pickupPos] call A3A_fnc_airTaxiFindLZ;
if (_pickupLZ isEqualTo []) exitWith { ["no_lz"] call _fnc_reject };
private _destPos = markerPos _destMarker;
private _destLZ = [_destPos, false] call A3A_fnc_airTaxiFindLZ;

// Fare
([_pickupPos, _destPos, _class] call A3A_fnc_airTaxiFare) params ["_money", "_hr", "", "_eta"];
if (_player getVariable ["moneyX", 0] < _money) exitWith { ["no_money", [_money]] call _fnc_reject };
if (server getVariable ["hr", 0] < _hr) exitWith { ["no_hr"] call _fnc_reject };

// Origin base
private _originMarker = [_pickupLZ] call A3A_fnc_airTaxiOrigin;
private _originPos = getMarkerPos _originMarker;
_originPos set [2, 50];

// Take the helicopter out of the garage, on the server and on every open garage dialog
_entry = +_entry;
private _recipients = +HR_GRG_Users;
_recipients pushBackUnique 2;
["remove", _vehUID] remoteExecCall ["A3A_fnc_airTaxiGarageSync", _recipients];

// Charge
if !([-_money, _player] call A3A_fnc_resourcesPlayer) exitWith {
    ["insert", _vehUID, _entry] remoteExecCall ["A3A_fnc_airTaxiGarageSync", _recipients];
    ["no_money", [_money]] call _fnc_reject;
};
[-_hr, 0, true] spawn A3A_fnc_resourcesFIA;

// Spawn and fly
([_class, _entry, _originPos, _pickupLZ, _player] call A3A_fnc_airTaxiSpawn) params ["_heli", "_crewGroup"];
if (isNull _heli || { !canMove _heli }) exitWith {
    [_player, _uid, _heli, _crewGroup, _vehUID, _entry, _money, _hr, "no_spawn"] call A3A_fnc_airTaxiFinish;
    ["no_spawn"] call _fnc_reject;
};

_player setVariable ["A3A_airTaxi", [_heli, "INBOUND"], true];
private _script = [_player, _uid, _heli, _crewGroup, _originPos, _pickupLZ, _destMarker, _destLZ, _vehUID, _entry, _money, _hr] spawn A3A_fnc_airTaxiRun;
A3A_airTaxiActive set [_uid, _script];

private _etaString = [[_eta] call A3A_fnc_secondsToTimeSpan, 0, 0, false, 2] call A3A_fnc_timeSpan_format;
["STR_A3A_fn_logistics_airTaxi_requested", [_dispName, _etaString]] remoteExecCall ["A3A_fnc_airTaxiHint", _client];
Info_5("Air taxi %1 (garage UID %2) requested by %3 to %4 for $%5", _dispName, _vehUID, name _player, _destMarker, _money);
