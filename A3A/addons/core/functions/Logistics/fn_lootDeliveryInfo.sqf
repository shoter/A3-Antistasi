/*
Maintainer: Shoter
    Prices and availability of a loot crate delivery for a player, shared by the dialog and the server
    request so both always agree. The commander pays from the faction funds, everyone else from their own money.
    The HR for the driver or pilot always comes from the faction pool.

    Price of both options: 1 HR + 50 * war level + deposit. The deposit is the price of the civilian car for
    the pickup and 1000 for the plane. Deposit and HR come back when the vehicle makes it home.

    Blocker keys (STR_A3A_fn_logistics_lootDelivery_blk_<key>):
        common: disabled, hq_moving, not_alive, water
        pickup: no_vehicle, no_hr, no_money
        plane:  no_vehicle, no_airport, no_hr, no_money

Arguments:
    <OBJECT> Player ordering the crate
    <POSITION> Drop position [DEFAULT = position of the player]

Return Value:
    <ARRAY> [
        <NUMBER> delivery fee, never refunded
        <BOOL> true when the faction funds pay (player is the commander)
        <NUMBER> funds available to the payer
        <NUMBER> faction HR available
        <ARRAY<STRING>> blockers for both options
        <ARRAY> pickup [<STRING> class, <NUMBER> deposit, <ARRAY<STRING>> blockers]
        <ARRAY> plane [<STRING> class, <NUMBER> deposit, <ARRAY<STRING>> blockers, <STRING> airport marker]
    ]

Scope: Any
Environment: Any
Public: No
Dependencies:
    A3A_fnc_vehiclePrice, tierWar, theBoss, airportsX, sidesX

Example:
    ([player] call A3A_fnc_lootDeliveryInfo) params ["_fee", "_factionPays", "_funds", "_hr", "_blockers", "_pickup", "_plane"];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

// Refundable deposit for the plane
#define PLANE_DEPOSIT 1000

params [["_player", objNull, [objNull]], ["_pos", [], [[]]]];
if (_pos isEqualTo [] && { !isNull _player }) then { _pos = getPosATL _player };

private _factionPays = !isNull _player && { _player == theBoss };
private _funds = if (_factionPays) then { server getVariable ["resourcesFIA", 0] } else { _player getVariable ["moneyX", 0] };
private _hr = server getVariable ["hr", 0];
private _fee = 50 * tierWar;

private _blockers = [];
if (LootToCrateRadius == 0) then { _blockers pushBack "disabled" };           // loot crates are switched off in the parameters
if (A3A_petrosMoving) then { _blockers pushBack "hq_moving" };
if (isNull _player || { !alive _player } || { _player getVariable ["incapacitated", false] }) then { _blockers pushBack "not_alive" };
if (_pos isNotEqualTo [] && { surfaceIsWater _pos }) then { _blockers pushBack "water" };

private _fnc_affordBlockers = {
    params ["_deposit"];
    private _result = [];
    if (_hr < 1) then { _result pushBack "no_hr" };
    if (_funds < _fee + _deposit) then { _result pushBack "no_money" };
    _result
};

// Pickup: the first civilian car of the rebel faction, the same one players can buy
private _pickupClass = FactionGet(reb,"vehiclesCivCar") param [0, ""];
private _pickupDeposit = 0;
private _pickupBlockers = [];
if (_pickupClass == "") then { _pickupBlockers pushBack "no_vehicle" } else {
    _pickupDeposit = [_pickupClass] call A3A_fnc_vehiclePrice;
    _pickupBlockers append ([_pickupDeposit] call _fnc_affordBlockers);
};

// Plane: civilian plane, starting above the closest rebel airport
private _planeClass = (FactionGet(reb,"vehiclesCivPlane") + FactionGet(reb,"vehiclesPlane")) param [0, ""];
private _planeBlockers = [];
private _airport = "";
private _airports = airportsX select { sidesX getVariable [_x, sideUnknown] == teamPlayer };
if (_planeClass == "") then { _planeBlockers pushBack "no_vehicle" };
if (_airports isEqualTo []) then { _planeBlockers pushBack "no_airport" } else {
    _airport = if (_pos isEqualTo []) then { _airports # 0 } else { [_airports, _pos] call BIS_fnc_nearestPosition };
};
if (_planeBlockers isEqualTo []) then { _planeBlockers append ([PLANE_DEPOSIT] call _fnc_affordBlockers) };

[_fee, _factionPays, _funds, _hr, _blockers, [_pickupClass, _pickupDeposit, _pickupBlockers], [_planeClass, PLANE_DEPOSIT, _planeBlockers, _airport]]
