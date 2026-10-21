/*
Maintainer: Shoter
    Client side of buying a repaired vehicle from the junkyard repair shop. Pre-checks, then the garage placement ghost.
    On placement the server is asked to take the money and the repair shop entry. The vehicle comes out repaired,
    without the junk status of the wrecks in the junkyard stock.

Arguments:
    <SCALAR> Entry id from A3A_junkyardRepairs
    <BOOL> Pay from faction funds (commander and sub-commanders only) [DEFAULT = false]

Return Value:
    <nil>

Scope: Clients
Environment: Scheduled
Public: No
Dependencies: HR_GRG_fnc_confirmPlacement, A3A_fnc_junkyardRepairPurchase, A3A_fnc_junkyardClock

Example:
    [12, false] spawn A3A_fnc_junkyardRepairBuy;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_id", -1, [0]], ["_useFactionFunds", false, [false]]];
private _titleStr = localize "STR_A3A_fn_junkyard_repair_title";

if (!isNil "HR_GRG_placing" && {HR_GRG_placing}) exitWith { [_titleStr, localize "STR_A3A_fn_reinf_addFIAVeh_no_placing"] call A3A_fnc_customHint };
if (player != player getVariable ["owner", player]) exitWith { [_titleStr, localize "STR_A3A_fn_reinf_addFIAVeh_no_control"] call A3A_fnc_customHint };
if ([getPosATL player] call A3A_fnc_enemyNearCheck) exitWith { [_titleStr, localize "STR_A3A_fn_reinf_addFIAVeh_no_enemy"] call A3A_fnc_customHint };
if !(player inArea "Synd_HQ") exitWith { [_titleStr, localize "STR_A3A_fn_junkyard_notAtHQ"] call A3A_fnc_customHint };

private _index = A3A_junkyardRepairs findIf { _x#0 == _id };
if (_index == -1) exitWith { [_titleStr, localize "STR_A3A_fn_junkyard_repair_gone"] call A3A_fnc_customHint };
(A3A_junkyardRepairs # _index) params ["", "_class", "_cost", "", "_readyAt"];
if (_readyAt > call A3A_fnc_junkyardClock) exitWith { [_titleStr, localize "STR_A3A_fn_junkyard_repair_notReady"] call A3A_fnc_customHint };

if (_useFactionFunds and {!([player] call A3A_fnc_isCommandStaff)}) then { _useFactionFunds = false };
private _funds = if (_useFactionFunds) then { server getVariable ["resourcesFIA", 0] } else { player getVariable ["moneyX", 0] };
if (_funds < _cost) exitWith { [_titleStr, format [localize "STR_A3A_fn_junkyard_repair_noMoney", _cost]] call A3A_fnc_customHint };

private _fnc_placed = {
    params ["_vehicle", "_useFactionFunds", "_id"];
    if (isNull _vehicle) exitWith {};
    if (!_useFactionFunds) then { _vehicle setVariable ["ownerX", getPlayerUID player, true] };
    [_vehicle, teamPlayer] call A3A_fnc_AIVehInit;
    [_vehicle, player, _id, _useFactionFunds] remoteExecCall ["A3A_fnc_junkyardRepairPurchase", 2];
};

private _extraMessage = format [localize "STR_A3A_fn_junkyard_repair_placing", _cost];
[_class, _fnc_placed, {[false]}, [_useFactionFunds, _id], nil, nil, nil, _extraMessage] call HR_GRG_fnc_confirmPlacement;
