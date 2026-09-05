/*
Maintainer: Shoter
    Checks whether a garage entry can serve as an air taxi.
    Eligible: any helicopter with passenger seats that is not an attack helicopter,
    not checked out, not a junkyard wreck and with at least a quarter tank.
    Lock ownership is not checked here because it depends on the requesting player.

Arguments:
    <ARRAY> Garage entry [displayName, class, lockUID, checkoutUID, state, lockName, customisation, lockTime]

Return Value:
    <STRING> Blocker key ("no_heli", "no_junk", "no_fuel") or "" when eligible

Scope: Server
Environment: Any
Public: No
Dependencies:
    A3A_faction_all, HR_GRG_Vehicles entry format (garage/Public/fn_addVehicle.sqf)

Example:
    [(HR_GRG_Vehicles#3) get _vehUID] call A3A_fnc_airTaxiEntryCheck;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_entry", [], [[]]]];
if (_entry isEqualTo []) exitWith { "no_heli" };
_entry params ["", ["_class", "", [""]], "", ["_checkedOut", "", [""]], ["_state", [], [[]]]];

if (_checkedOut isNotEqualTo "") exitWith { "no_heli" };
if !(_class isKindOf "Helicopter") exitWith { "no_heli" };
if (getNumber (configFile >> "CfgVehicles" >> _class >> "transportSoldier") < 1) exitWith { "no_heli" };
if (_class in (FactionGet(all,"vehiclesHelisAttack") + FactionGet(all,"vehiclesHelisLightAttack"))) exitWith { "no_heli" };

// Junkyard wreck: deadline lives in the damage state, see HR_GRG_fnc_getDamage / garage/Core/fn_reloadCategory.sqf
private _dmgStats = _state param [1, []];
private _junkUntil = if (_dmgStats isEqualType []) then { _dmgStats param [3, -1] } else { -1 };
if (_junkUntil isEqualType 0 && { _junkUntil > (call A3A_fnc_junkyardClock) }) exitWith { "no_junk" };

// Fuel state is a plain number when the vehicle has no fuel cargo (HR_GRG_reduceState), otherwise [fuel, cargo, aceCargo]
private _fuelStats = _state param [0, 1];
private _fuel = if (_fuelStats isEqualType []) then { _fuelStats param [0, 1] } else { _fuelStats };
if (_fuel isEqualType 0 && { _fuel < 0.25 }) exitWith { "no_fuel" };

""
