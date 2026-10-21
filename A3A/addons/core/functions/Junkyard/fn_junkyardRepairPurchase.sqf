/*
Maintainer: Shoter
    Server side of buying a repaired vehicle from the junkyard repair shop. Called after the client has placed the vehicle.
    Verifies the entry is still there, repaired and of the placed class, and takes the money. On failure the placed vehicle is deleted.

Arguments:
    <OBJECT> The placed vehicle
    <OBJECT> Buying player
    <SCALAR> Entry id from A3A_junkyardRepairs
    <BOOL> Pay from faction funds (commander and sub-commanders only) [DEFAULT = false]

Return Value:
    <nil>

Scope: Server
Environment: Unscheduled
Public: No
Dependencies: A3A_fnc_resourcesFIA, A3A_fnc_resourcesPlayer, A3A_fnc_rebelVehPlacedWorker, A3A_fnc_junkyardClock

Example:
    [_vehicle, player, 12, true] remoteExecCall ["A3A_fnc_junkyardRepairPurchase", 2];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if !(isServer) exitWith { Error("Attempted to call server function as non-server") };
params [["_vehicle", objNull, [objNull]], ["_player", objNull, [objNull]], ["_id", -1, [0]], ["_useFactionFunds", false, [false]]];
if (isNull _vehicle or isNull _player) exitWith {};

private _titleStr = localize "STR_A3A_fn_junkyard_repair_title";
private _class = typeOf _vehicle;
private _fnc_fail = {
    params ["_text"];
    deleteVehicle _vehicle;
    [_titleStr, _text] remoteExec ["A3A_fnc_customHint", _player];
    Info_3("Junkyard repair purchase of %1 by %2 failed: %3", _class, name _player, _text);
};

private _index = A3A_junkyardRepairs findIf { _x#0 == _id };
if (_index == -1 or {A3A_junkyardRepairs # _index # 1 != _class}) exitWith { [localize "STR_A3A_fn_junkyard_repair_gone"] call _fnc_fail };
(A3A_junkyardRepairs # _index) params ["", "", "_cost", "", "_readyAt"];
if (_readyAt > call A3A_fnc_junkyardClock) exitWith { [localize "STR_A3A_fn_junkyard_repair_notReady"] call _fnc_fail };

if (_useFactionFunds and {!([_player] call A3A_fnc_isCommandStaff)}) then { _useFactionFunds = false };
private _paid = if (_useFactionFunds) then {
    if (server getVariable ["resourcesFIA", 0] < _cost) then { false } else { [0, -_cost] call A3A_fnc_resourcesFIA; true };
} else {
    [-_cost, _player] call A3A_fnc_resourcesPlayer;
};
if (!_paid) exitWith { [format [localize "STR_A3A_fn_junkyard_repair_noMoney", _cost]] call _fnc_fail };

A3A_junkyardRepairs deleteAt _index;
publicVariable "A3A_junkyardRepairs";
[[_player] call A3A_fnc_playerStats_getUID, [["vehiclesBought", 1]]] call A3A_fnc_playerStats_add;

[_vehicle] spawn A3A_fnc_rebelVehPlacedWorker;

private _displayName = getText (configFile >> "CfgVehicles" >> _class >> "displayName");
[_titleStr, format [localize "STR_A3A_fn_junkyard_repair_bought", _displayName, _cost]] remoteExec ["A3A_fnc_customHint", _player];
// The commander hears about faction money spent by sub-commanders
if (_useFactionFunds) then { [_player, _displayName, _cost, 0] call A3A_fnc_subCommanderSpent };
Info_3("Junkyard repair: %1 bought %2 for %3", name _player, _class, _cost);
