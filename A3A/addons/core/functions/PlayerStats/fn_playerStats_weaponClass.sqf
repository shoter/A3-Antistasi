/*
Maintainer: Shoter
    Returns the key under which the weapon a unit is using right now is tracked in the player statistics:
    the vehicle class while mounted, otherwise the class of the weapon in hand. Muzzle names that currentWeapon
    reports for underbarrel launchers are mapped back to their weapon.

Arguments:
    <OBJECT> Unit

Return Value:
    <STRING> Weapon or vehicle class, "" when the unit holds nothing trackable (unarmed, throwing, placing)

Scope: Any
Environment: Any
Public: No

Example:
    [player] call A3A_fnc_playerStats_weaponClass;

License: APL-ND

*/

params [["_unit", objNull, [objNull]]];

if (isNull _unit) exitWith { "" };

private _vehicle = vehicle _unit;
if (_vehicle != _unit) exitWith { typeOf _vehicle };

private _weapon = currentWeapon _unit;
if (_weapon in ["", "Throw", "Put"]) exitWith { "" };
if (isClass (configFile >> "CfgWeapons" >> _weapon)) exitWith { _weapon };

// A muzzle name, find the carried weapon it belongs to. The lookup is cached per machine.
if (isNil "A3A_playerStats_muzzleCache") then { A3A_playerStats_muzzleCache = createHashMap };
private _cached = A3A_playerStats_muzzleCache get _weapon;
if (!isNil "_cached") exitWith { _cached };

private _owner = "";
{
    if (_weapon in (getArray (configFile >> "CfgWeapons" >> _x >> "muzzles"))) exitWith { _owner = _x };
} forEach weapons _unit;
if (_owner != "") then { A3A_playerStats_muzzleCache set [_weapon, _owner] };
_owner
