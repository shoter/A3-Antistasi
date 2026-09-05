/*
Maintainer: Shoter
    Sends a client the garaged ammo trucks that can be sent on a garrison resupply run, with their ammo points.
    Entries checked out, locked by someone else, still a junkyard wreck or without any ammo points are left out.

Arguments:
    <OBJECT> Player asking for the list
    <NUMBER> Client id to reply to (clientOwner of the requester)

Return Value:
    <nil>

Scope: Server
Environment: Unscheduled
Public: No
Dependencies:
    HR_GRG_Vehicles, HR_GRG_canOverrideLock, HR_GRG_fnc_isAmmoSource, A3A_resourceVehValues

Example:
    [player, clientOwner] remoteExecCall ["A3A_fnc_garrisonResupplyListTrucks", 2];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_player", objNull, [objNull]], ["_client", -1, [0]]];
if (!isServer) exitWith { Error("Called on a client, server only") };
if (isNull _player || _client < 0) exitWith {};
if (isNil "HR_GRG_Vehicles") then { [] call HR_GRG_fnc_initServer };

private _uid = getPlayerUID _player;
private _canOverride = _player call HR_GRG_canOverrideLock;

private _list = [];
{
    private _points = [_y, _uid, _canOverride] call A3A_fnc_garrisonResupplyTruckPoints;
    if (_points <= 0) then { continue };
    _list pushBack [_x, _y # 0, _points];
} forEach (HR_GRG_Vehicles # 6);      // support vehicle category, see garage/Core/fn_getCatIndex.sqf

Debug_2("Resupply truck list for %1: %2", name _player, count _list);
["trucksReceived", [_list]] remoteExecCall ["A3A_GUI_fnc_garrisonsTab", _client];
