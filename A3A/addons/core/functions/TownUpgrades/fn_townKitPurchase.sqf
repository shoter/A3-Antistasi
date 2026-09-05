/*
Maintainer: Shoter
    Server side of buying a town upgrade kit. Called after the client has placed the crate ghost at HQ.
    Re-validates commander, town, funds and duplicates, takes the faction money and creates the tracked crate.

Arguments:
    <STRING> Upgrade id, key of A3A_townUpgradeHM
    <STRING> City marker name the kit is bound to
    <ARRAY> Crate position ATL
    <SCALAR> Crate direction
    <OBJECT> Buying player

Return Value:
    <nil>

Scope: Server
Environment: Unscheduled
Public: No
Dependencies: A3A_fnc_resourcesFIA, A3A_fnc_townKitCreate, A3A_fnc_townUpgradePrice

Example:
    ["clinic", "Kavala", getPosATL player, getDir player, player] remoteExecCall ["A3A_fnc_townKitPurchase", 2];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if !(isServer) exitWith { Error("Attempted to call server function as non-server") };
params [["_id", "", [""]], ["_city", "", [""]], ["_pos", [], [[]]], ["_dir", 0, [0]], ["_player", objNull, [objNull]]];
if (isNull _player) exitWith {};

private _titleStr = localize "STR_A3A_fn_townUpgrades_title";
private _fnc_fail = {
    params ["_text"];
    [_titleStr, _text] remoteExec ["A3A_fnc_customHint", _player];
    Info_4("Town kit purchase of %1 for %2 by %3 failed: %4", _id, _city, name _player, _text);
};

if (_player != theBoss) exitWith { [localize "STR_A3A_fn_townUpgrades_commanderOnly"] call _fnc_fail };
if !(_id in A3A_townUpgradeHM and {_city in citiesX}) exitWith { Error_2("Bad town kit request: %1 for %2", _id, _city) };
if (_pos isEqualTo [] or {_pos distance2D _player > 75}) exitWith { Error_2("Town kit position %1 too far from %2", _pos, name _player) };
if (sidesX getVariable [_city, sideUnknown] != teamPlayer or {_city in destroyedSites}) exitWith { [format [localize "STR_A3A_fn_townUpgrades_townNotRebel", _city]] call _fnc_fail };
private _name = localize format ["STR_A3A_fn_townUpgrades_name_%1", _id];
if ([_city, _id] call A3A_fnc_townUpgradeHas) exitWith { [format [localize "STR_A3A_fn_townUpgrades_alreadyInstalled", _city, _name]] call _fnc_fail };

// One kit of each type per town, the same as installed upgrades
private _duplicate = A3A_townKits findIf { !isNull _x and {(_x getVariable ["A3A_townKit", ["", ""]]) select [0, 2] isEqualTo [_id, _city]} };
if (_duplicate != -1) exitWith { [format [localize "STR_A3A_fn_townUpgrades_kitExists", _name, _city]] call _fnc_fail };

private _cost = [_id, _city] call A3A_fnc_townUpgradePrice;
if (server getVariable ["resourcesFIA", 0] < _cost) exitWith { [format [localize "STR_A3A_fn_townUpgrades_noMoney", _cost]] call _fnc_fail };
[0, -_cost] call A3A_fnc_resourcesFIA;

private _crate = [_id, _city, _pos, _dir, _cost] call A3A_fnc_townKitCreate;
if (isNull _crate) exitWith { [0, _cost] call A3A_fnc_resourcesFIA; Error_1("Town kit %1 could not be created, refunded", _id) };

[_titleStr, format [localize "STR_A3A_fn_townUpgrades_bought", _name, _city, _cost, A3A_townUpgradeRadius]] remoteExec ["A3A_fnc_customHint", _player];
Info_4("Town kit %1 for %2 bought by %3 for %4", _id, _city, name _player, _cost);
