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
Dependencies: A3A_fnc_getVehicleWeaponClasses

Example:
    ["B_MRAP_01_hmg_F"] call A3A_fnc_getVehicleWeapons;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_class", "", [""]]];
private _cfg = configFile >> "CfgVehicles" >> _class;
if !(isClass _cfg) exitWith { [] };

private _weaponsCfg = configFile >> "CfgWeapons";
private _names = [];
{
    _names pushBackUnique getText (_weaponsCfg >> _x >> "displayName");
} forEach ([_class] call A3A_fnc_getVehicleWeaponClasses);

if (isClass (_cfg >> "Components" >> "TransportPylonsComponent")) then {
    _names pushBackUnique (localize "STR_A3A_fn_junkyard_pylons");
};

_names;
