/*
Maintainer: Shoter
    Server side of a junkyard purchase. Called after the client has placed the vehicle.
    Verifies the vehicle is still in stock and takes the money. On failure the placed vehicle is deleted.

Arguments:
    <OBJECT> The placed vehicle
    <OBJECT> Buying player
    <BOOL> Pay from faction funds (commander only) [DEFAULT = false]

Return Value:
    <nil>

Scope: Server
Environment: Unscheduled
Public: No
Dependencies: A3A_fnc_resourcesFIA, A3A_fnc_resourcesPlayer, A3A_fnc_rebelVehPlacedWorker

Example:
    [_vehicle, player, true] remoteExecCall ["A3A_fnc_junkyardPurchase", 2];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if !(isServer) exitWith { Error("Attempted to call server function as non-server") };
params [["_vehicle", objNull, [objNull]], ["_player", objNull, [objNull]], ["_useFactionFunds", false, [false]]];
if (isNull _vehicle or isNull _player) exitWith {};

private _titleStr = localize "STR_A3A_fn_junkyard_title";
private _class = typeOf _vehicle;
private _fnc_fail = {
    params ["_text"];
    deleteVehicle _vehicle;
    [_titleStr, _text] remoteExec ["A3A_fnc_customHint", _player];
    Info_2("Junkyard purchase of %1 by %2 failed: %3", _class, name _player, _text);
};

private _index = A3A_junkyardStock findIf { _x#0 == _class };
if (_index == -1) exitWith { [localize "STR_A3A_fn_junkyard_soldOut"] call _fnc_fail };
private _cost = A3A_junkyardStock # _index # 1;

if (_useFactionFunds and {_player != theBoss}) then { _useFactionFunds = false };
private _paid = if (_useFactionFunds) then {
    if (server getVariable ["resourcesFIA", 0] < _cost) then { false } else { [0, -_cost] call A3A_fnc_resourcesFIA; true };
} else {
    [-_cost, _player] call A3A_fnc_resourcesPlayer;
};
if (!_paid) exitWith { [format [localize "STR_A3A_fn_junkyard_noMoney", _cost]] call _fnc_fail };

A3A_junkyardStock deleteAt _index;
[[_player] call A3A_fnc_playerStats_getUID, [["vehiclesBought", 1]]] call A3A_fnc_playerStats_add;
publicVariable "A3A_junkyardStock";

[_vehicle] spawn A3A_fnc_rebelVehPlacedWorker;

private _displayName = getText (configFile >> "CfgVehicles" >> _class >> "displayName");
private _junkTime = [A3A_junkyardJunkDuration, 1, 1, false, 2, false, true] call A3A_fnc_timeSpan_format;
[_titleStr, format [localize "STR_A3A_fn_junkyard_bought", _displayName, _cost, _junkTime]] remoteExec ["A3A_fnc_customHint", _player];
Info_3("Junkyard: %1 bought %2 for %3", name _player, _class, _cost);
