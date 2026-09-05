/*
Maintainer: Shoter
    Lists the display names of the real weapons of a vehicle class, from config.
    Walks all turrets. Horns, smoke launchers, countermeasures and laser designators are ignored.

Arguments:
    <STRING> Vehicle class name

Return Value:
    <ARRAY<STRING>> Unique weapon display names. Contains the localized "pylon weapons" entry when the vehicle has dynamic pylons.

Scope: Anywhere
Environment: Any
Public: Yes
Dependencies:

Example:
    ["B_MRAP_01_hmg_F"] call A3A_fnc_getVehicleWeapons;
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
private _names = [];
{
    private _weaponCfg = _weaponsCfg >> _x;
    if !(isClass _weaponCfg) then { continue };
    private _weapon = _x;
    if (_ignoredParents findIf { _weapon isKindOf [_x, _weaponsCfg] } != -1) then { continue };
    private _name = getText (_weaponCfg >> "displayName");
    if (_name == "" or {"horn" in toLower _name}) then { continue };
    _names pushBackUnique _name;
} forEach (_weapons arrayIntersect _weapons);

if (isClass (_cfg >> "Components" >> "TransportPylonsComponent")) then {
    _names pushBackUnique (localize "STR_A3A_fn_junkyard_pylons");
};

_names;
