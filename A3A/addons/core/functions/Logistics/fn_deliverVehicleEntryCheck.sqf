/*
Maintainer: Shoter
    Checks whether a garage entry can be delivered by an AI driver.
    Eligible: any crewed land vehicle with a driver seat (cars, armour, support trucks) that is
    not checked out, not a junkyard wreck and has at least a fifth of a tank.
    Lock ownership is not checked here because it depends on the requesting player.

Arguments:
    <ARRAY> Garage entry [displayName, class, lockUID, checkoutUID, state, lockName, customisation, lockTime]

Return Value:
    <STRING> Blocker key ("no_vehicle", "no_junk", "no_fuel") or "" when eligible

Scope: Server
Environment: Any
Public: No
Dependencies:
    HR_GRG_Vehicles entry format (garage/Public/fn_addVehicle.sqf)

Example:
    [(HR_GRG_Vehicles#1) get _vehUID] call A3A_fnc_deliverVehicleEntryCheck;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_entry", [], [[]]]];
if (_entry isEqualTo []) exitWith { "no_vehicle" };
_entry params ["", ["_class", "", [""]], "", ["_checkedOut", "", [""]], ["_state", [], [[]]]];

private _config = configFile >> "CfgVehicles" >> _class;
if (_checkedOut isNotEqualTo "") exitWith { "no_vehicle" };
if (!(_class isKindOf "LandVehicle") || { _class isKindOf "StaticWeapon" }) exitWith { "no_vehicle" };
if (getNumber (_config >> "hasDriver") < 1 || { getNumber (_config >> "isUav") > 0 }) exitWith { "no_vehicle" };

// Junkyard wreck: deadline lives in the damage state, see HR_GRG_fnc_getDamage / garage/Core/fn_reloadCategory.sqf
private _dmgStats = _state param [1, []];
private _junkUntil = if (_dmgStats isEqualType []) then { _dmgStats param [3, -1] } else { -1 };
if (_junkUntil isEqualType 0 && { _junkUntil > (call A3A_fnc_junkyardClock) }) exitWith { "no_junk" };

// Fuel state is a plain number when the vehicle has no fuel cargo (HR_GRG_reduceState), otherwise [fuel, cargo, aceCargo]
private _fuelStats = _state param [0, 1];
private _fuel = if (_fuelStats isEqualType []) then { _fuelStats param [0, 1] } else { _fuelStats };
if (_fuel isEqualType 0 && { _fuel < 0.2 }) exitWith { "no_fuel" };

""
