/*
Maintainer: Shoter
    Sends a client the garaged land vehicles that can be delivered by an AI driver.
    Entries locked by someone else are included but flagged so the UI can grey them out.

Arguments:
    <OBJECT> Player asking for the list
    <NUMBER> Client id to reply to (clientOwner of the requester)

Return Value:
    <nil>

Scope: Server
Environment: Unscheduled
Public: No
Dependencies:
    HR_GRG_Vehicles, HR_GRG_canOverrideLock

Example:
    [player, clientOwner] remoteExecCall ["A3A_fnc_deliverVehicleListVehicles", 2];
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
    private _catIndex = _x;
    {
        if (([_y] call A3A_fnc_deliverVehicleEntryCheck) != "") then { continue };
        _y params ["_dispName", "_class", "_lockUID"];
        private _lockedByOther = _lockUID isNotEqualTo "" && { _lockUID != _uid } && { !_canOverride };
        _list pushBack [_catIndex, _x, _class, _dispName, _lockedByOther];
    } forEach (HR_GRG_Vehicles # _catIndex);
} forEach [0, 1, 2, 6];      // undercover cars, cars, armour, support vehicles, see garage/Core/fn_getCatIndex.sqf

Debug_2("Vehicle delivery list for %1: %2", name _player, count _list);
["receiveVehicles", [_list]] remoteExecCall ["A3A_GUI_fnc_deliverVehicleTab", _client];
