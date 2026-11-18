/*
Maintainer: Shoter
    Server side of cancelling a repair in the junkyard repair shop: the vehicle leaves the list for good, whether it is
    still in repair or already repaired. Nothing is refunded: the player who retrieved the wreck kept the smaller
    retrieve pay. Commander and sub-commanders only, as the list is shared by the whole faction.
    An open Junkyard dialog picks up the change by itself.

Arguments:
    <OBJECT> Requesting player
    <SCALAR> Entry id from A3A_junkyardRepairs

Return Value:
    <nil>

Scope: Server
Environment: Unscheduled
Public: No
Dependencies: A3A_fnc_isCommandStaff

Example:
    [player, 12] remoteExecCall ["A3A_fnc_junkyardRepairCancel", 2];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if !(isServer) exitWith { Error("Attempted to call server function as non-server") };
params [["_player", objNull, [objNull]], ["_id", -1, [0]]];
if (isNull _player) exitWith {};

private _titleStr = localize "STR_A3A_fn_junkyard_repair_title";
if !([_player] call A3A_fnc_isCommandStaff) exitWith {
    [_titleStr, localize "STR_A3A_fn_junkyard_repair_cancelNoRights"] remoteExec ["A3A_fnc_customHint", _player];
    Info_1("Junkyard repair: cancel by %1 refused, not command staff", name _player);
};

private _index = A3A_junkyardRepairs findIf { _x#0 == _id };
if (_index == -1) exitWith { [_titleStr, localize "STR_A3A_fn_junkyard_repair_gone"] remoteExec ["A3A_fnc_customHint", _player] };

private _class = (A3A_junkyardRepairs deleteAt _index) # 1;
publicVariable "A3A_junkyardRepairs";

private _displayName = getText (configFile >> "CfgVehicles" >> _class >> "displayName");
[_titleStr, format [localize "STR_A3A_fn_junkyard_repair_cancelled", _displayName]] remoteExec ["A3A_fnc_customHint", _player];
Info_2("Junkyard repair: %1 cancelled the repair of %2", name _player, _class);
