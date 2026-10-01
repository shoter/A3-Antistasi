/*
Maintainer: Shoter
    Loads part of the bribe for the buying intel task (A3A_tasks_fnc_LOG_BuyIntel) into the money truck,
    from the player's own money. Called from the bribe money dialog (A3A_GUI_fnc_buyIntelDialog).
    Never takes more than the bribe still needs. Unlocks the truck once the whole bribe is loaded.
    Re-executes itself on the server when called on a client.

Arguments:
    <OBJECT> Player who pays
    <OBJECT> Money truck
    <SCALAR> Euros to load

Return Value:
    <nil>

Scope: Server, Global Arguments, Global Effect
Environment: Unscheduled
Public: No

Example:
    [player, A3A_GUI_buyIntelTruck, 500] remoteExecCall ["A3A_tasks_fnc_LOG_BuyIntel_deposit", 2];
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_player", objNull, [objNull]], ["_truck", objNull, [objNull]], ["_amount", 0, [0]]];

if (!isServer) exitWith { _this remoteExecCall [QFUNC(LOG_BuyIntel_deposit), 2] };
if (!isPlayer _player or !alive _truck) exitWith {};
if !(_truck getVariable ["A3A_buyIntelOpen", false]) exitWith {};
if (_player distance _truck > 15) exitWith {};

private _title = localize "STR_A3A_Tasks_LOG_BuyIntel_title";
private _cost = _truck getVariable ["A3A_buyIntelCost", 1000];
private _loaded = _truck getVariable ["A3A_buyIntelMoney", 0];
_amount = (floor _amount) min (_cost - _loaded);
if (_amount <= 0) exitWith {};

if !([-_amount, _player] call A3A_fnc_resourcesPlayer) exitWith {
    [_title, format [localize "STR_A3A_Tasks_LOG_BuyIntel_noMoney", _amount]] remoteExecCall ["A3A_fnc_customHint", _player];
};

_loaded = _loaded + _amount;
_truck setVariable ["A3A_buyIntelMoney", _loaded, true];
[[_player] call A3A_fnc_playerStats_getUID, [["moneyDonated", _amount]]] call A3A_fnc_playerStats_add;
Info_4("%1 [UID: %2] loaded %3 into the buying intel truck, now %4", name _player, getPlayerUID _player, _amount, _loaded);

if (_loaded < _cost) exitWith {
    [_title, format [localize "STR_A3A_Tasks_LOG_BuyIntel_loaded", _amount, _loaded, _cost]] remoteExecCall ["A3A_fnc_customHint", _player];
};

[_truck, 0] remoteExec ["lock", _truck];
[_title, localize "STR_A3A_Tasks_LOG_BuyIntel_full", getPosATL _truck, 300] call FUNC(hintNear);
