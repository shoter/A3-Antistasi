/*
Maintainer: Shoter
    Lists the real weapon classes of a vehicle class, from config.
    Walks all turrets. Horns, smoke launchers, countermeasures, laser designators and weapons without a display name are ignored.
    Dynamic pylons are not weapons in config, see A3A_fnc_getVehicleWeaponTiers for those.

Arguments:
    <STRING> Vehicle class name

Return Value:
    <ARRAY<STRING>> Unique weapon class names

Scope: Anywhere
Environment: Any
Public: Yes
Dependencies:

Example:
    ["B_MRAP_01_hmg_F"] call A3A_fnc_getVehicleWeaponClasses;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_class", "", [""]]];
private _cfg = configFile >> "CfgVehicles" >> _class;
if !(isClass _cfg) exitWith { [] };

private _weapons = +getArray (_cfg >> "weapons");
private _fnc_turrets = {
    {
        _weapons append getArray (_x >> "weapons");
        if (isClass (_x >> "Turrets")) then { _x call _fnc_turrets };
    } forEach ("true" configClasses (_this >> "Turrets"));
};
_cfg call _fnc_turrets;

private _ignoredParents = ["CarHorn", "TruckHorn", "SportCarHorn", "MiniCarHorn", "BikeHorn", "Horn", "SmokeLauncher", "CMFlareLauncher", "Laserdesignator_mounted", "Laserdesignator", "FakeWeapon"];
private _weaponsCfg = configFile >> "CfgWeapons";
(_weapons arrayIntersect _weapons) select {
    private _weapon = _x;
    private _weaponCfg = _weaponsCfg >> _weapon;
    isClass _weaponCfg
    and {_ignoredParents findIf { _weapon isKindOf [_x, _weaponsCfg] } == -1}
    and {
        private _name = getText (_weaponCfg >> "displayName");
        _name != "" and {!("horn" in toLower _name)}
    }
};
