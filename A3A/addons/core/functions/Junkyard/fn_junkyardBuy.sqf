/*
Maintainer: Shoter
    Client side of a junkyard purchase. Pre-checks, then the garage placement ghost.
    On placement the vehicle gets its wreck state and the server is asked to take the money and stock entry.

Arguments:
    <STRING> Vehicle class from A3A_junkyardStock
    <BOOL> Pay from faction funds (commander only) [DEFAULT = false]

Return Value:
    <nil>

Scope: Clients
Environment: Scheduled
Public: No
Dependencies: HR_GRG_fnc_confirmPlacement, A3A_fnc_junkyardPurchase, A3A_fnc_junkyardApplyWreckState

Example:
    ["C_Offroad_01_F", false] spawn A3A_fnc_junkyardBuy;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_class", "", [""]], ["_useFactionFunds", false, [false]]];
private _titleStr = localize "STR_A3A_fn_junkyard_title";

if (!isNil "HR_GRG_placing" && {HR_GRG_placing}) exitWith { [_titleStr, localize "STR_A3A_fn_reinf_addFIAVeh_no_placing"] call A3A_fnc_customHint };
if (player != player getVariable ["owner", player]) exitWith { [_titleStr, localize "STR_A3A_fn_reinf_addFIAVeh_no_control"] call A3A_fnc_customHint };
if ([getPosATL player] call A3A_fnc_enemyNearCheck) exitWith { [_titleStr, localize "STR_A3A_fn_reinf_addFIAVeh_no_enemy"] call A3A_fnc_customHint };
if !(player inArea "Synd_HQ") exitWith { [_titleStr, localize "STR_A3A_fn_junkyard_notAtHQ"] call A3A_fnc_customHint };

private _index = A3A_junkyardStock findIf { _x#0 == _class };
if (_index == -1) exitWith { [_titleStr, localize "STR_A3A_fn_junkyard_soldOut"] call A3A_fnc_customHint };
private _cost = A3A_junkyardStock # _index # 1;

if (_useFactionFunds and {player != theBoss}) then { _useFactionFunds = false };
private _funds = if (_useFactionFunds) then { server getVariable ["resourcesFIA", 0] } else { player getVariable ["moneyX", 0] };
if (_funds < _cost) exitWith { [_titleStr, format [localize "STR_A3A_fn_junkyard_noMoney", _cost]] call A3A_fnc_customHint };

private _fnc_placed = {
    params ["_vehicle", "_useFactionFunds"];
    if (isNull _vehicle) exitWith {};
    if (!_useFactionFunds) then { _vehicle setVariable ["ownerX", getPlayerUID player, true] };
    // Wreck state first, while the vehicle is still local to us and before the server garrisons it
    [_vehicle] call A3A_fnc_junkyardApplyWreckState;
    [_vehicle, teamPlayer] call A3A_fnc_AIVehInit;
    [_vehicle, player, _useFactionFunds] remoteExecCall ["A3A_fnc_junkyardPurchase", 2];
};

private _extraMessage = format [localize "STR_A3A_fn_junkyard_placing", _cost];
[_class, _fnc_placed, {[false]}, [_useFactionFunds], nil, nil, nil, _extraMessage] call HR_GRG_fnc_confirmPlacement;
