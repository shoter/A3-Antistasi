/*
Maintainer: Shoter
    Client side of buying a town upgrade kit for a chosen town. Pre-checks, then the garage placement ghost for the crate.
    On placement the server is asked to take the faction money and create the tracked crate.

Arguments:
    <STRING> Upgrade id, key of A3A_townUpgradeHM
    <STRING> City marker name the kit is bound to

Return Value:
    <nil>

Scope: Clients
Environment: Scheduled
Public: No
Dependencies: HR_GRG_fnc_confirmPlacement, A3A_fnc_townKitPurchase

Example:
    ["clinic", "Kavala"] spawn A3A_fnc_townKitBuy;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_id", "", [""]], ["_city", "", [""]]];
private _titleStr = localize "STR_A3A_fn_townUpgrades_title";

if (!isNil "HR_GRG_placing" && {HR_GRG_placing}) exitWith { [_titleStr, localize "STR_A3A_fn_reinf_addFIAVeh_no_placing"] call A3A_fnc_customHint };
if (player != player getVariable ["owner", player]) exitWith { [_titleStr, localize "STR_A3A_fn_reinf_addFIAVeh_no_control"] call A3A_fnc_customHint };
if (player != theBoss) exitWith { [_titleStr, localize "STR_A3A_fn_townUpgrades_commanderOnly"] call A3A_fnc_customHint };
if ([getPosATL player] call A3A_fnc_enemyNearCheck) exitWith { [_titleStr, localize "STR_A3A_fn_reinf_addFIAVeh_no_enemy"] call A3A_fnc_customHint };
if !(player inArea "Synd_HQ") exitWith { [_titleStr, localize "STR_A3A_fn_townUpgrades_notAtHQ"] call A3A_fnc_customHint };
if !(_id in A3A_townUpgradeHM) exitWith { Error_1("Unknown town upgrade %1", _id) };
if (sidesX getVariable [_city, sideUnknown] != teamPlayer or {_city in destroyedSites}) exitWith { [_titleStr, format [localize "STR_A3A_fn_townUpgrades_townNotRebel", _city]] call A3A_fnc_customHint };
private _name = localize format ["STR_A3A_fn_townUpgrades_name_%1", _id];
if ([_city, _id] call A3A_fnc_townUpgradeHas) exitWith { [_titleStr, format [localize "STR_A3A_fn_townUpgrades_alreadyInstalled", _city, _name]] call A3A_fnc_customHint };

private _cost = [_id, _city] call A3A_fnc_townUpgradePrice;
if (server getVariable ["resourcesFIA", 0] < _cost) exitWith { [_titleStr, format [localize "STR_A3A_fn_townUpgrades_noMoney", _cost]] call A3A_fnc_customHint };

private _fnc_placed = {
    params ["_crate", "_id", "_city"];
    if (isNull _crate) exitWith {};          // placement cancelled
    // The server owns every tracked object: recreate it there
    private _pos = getPosATL _crate;
    private _dir = getDir _crate;
    deleteVehicle _crate;
    [_id, _city, _pos, _dir, player] remoteExecCall ["A3A_fnc_townKitPurchase", 2];
};

private _extraMessage = format [localize "STR_A3A_fn_townUpgrades_placingKit", _name, _city, _cost];
[A3A_townUpgradeCrateClass, _fnc_placed, {[false]}, [_id, _city], nil, nil, nil, _extraMessage] call HR_GRG_fnc_confirmPlacement;
