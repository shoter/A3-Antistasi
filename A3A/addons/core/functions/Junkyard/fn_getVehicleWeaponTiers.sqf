/*
Maintainer: Shoter
    Rates the armament of a vehicle class for pricing. One tier per real weapon, plus one for the default
    pylon loadout when the vehicle has dynamic pylons. A weapon's tier is that of the strongest magazine it accepts:
        3 - guided missiles, bombs, tank guns, artillery shells and heavy rockets
        2 - autocannons and rocket pods
        1 - machine guns, grenade launchers and anything else
    Tune the two thresholds below; the tier multipliers live in A3A_fnc_junkyardPrice.

Arguments:
    <STRING> Vehicle class name

Return Value:
    <ARRAY<SCALAR>> Tiers, highest first. Empty for unarmed vehicles.

Scope: Anywhere
Environment: Any
Public: Yes
Dependencies: A3A_fnc_getVehicleWeaponClasses

Example:
    ["O_MBT_02_cannon_F"] call A3A_fnc_getVehicleWeaponTiers;    // [3, 1, 1]
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

// Bullets with at least this hit value count as autocannon rounds: 12.7 mm stays below, 20 mm and up are above
#define AUTOCANNON_HIT 30
// Unguided rockets with at least this hit value count as artillery
#define HEAVY_ROCKET_HIT 100

params [["_class", "", [""]]];
private _cfg = configFile >> "CfgVehicles" >> _class;
if !(isClass _cfg) exitWith { [] };

private _weaponsCfg = configFile >> "CfgWeapons";
private _magazinesCfg = configFile >> "CfgMagazines";
private _ammoCfg = configFile >> "CfgAmmo";
private _wellsCfg = configFile >> "CfgMagazineWells";

private _fnc_ammoTier = {
    params ["_ammo"];
    if (_ammo == "" or {!isClass (_ammoCfg >> _ammo)}) exitWith { 0 };
    if (_ammo isKindOf ["MissileBase", _ammoCfg] or {_ammo isKindOf ["BombCore", _ammoCfg]} or {_ammo isKindOf ["ShellBase", _ammoCfg]}) exitWith { 3 };
    private _hit = getNumber (_ammoCfg >> _ammo >> "hit");
    if (_ammo isKindOf ["RocketBase", _ammoCfg]) exitWith { [2, 3] select (_hit >= HEAVY_ROCKET_HIT) };
    if (_ammo isKindOf ["BulletBase", _ammoCfg] and {_hit >= AUTOCANNON_HIT}) exitWith { 2 };
    1
};

private _fnc_magazineTier = {
    params ["_magazine"];
    [getText (_magazinesCfg >> _magazine >> "ammo")] call _fnc_ammoTier;
};

// Magazines a weapon or muzzle accepts: its own list plus its magazine wells
private _fnc_magazinesOf = {
    params ["_weaponCfg"];
    private _magazines = +getArray (_weaponCfg >> "magazines");
    {
        { _magazines append getArray _x } forEach configProperties [_wellsCfg >> _x, "isArray _x"];
    } forEach getArray (_weaponCfg >> "magazineWell");
    _magazines;
};

private _tiers = [];
{
    private _weaponCfg = _weaponsCfg >> _x;
    private _magazines = [_weaponCfg] call _fnc_magazinesOf;
    {
        if (_x != "this" and {isClass (_weaponCfg >> _x)}) then { _magazines append ([_weaponCfg >> _x] call _fnc_magazinesOf) };
    } forEach getArray (_weaponCfg >> "muzzles");
    private _tier = 1;
    { _tier = _tier max ([_x] call _fnc_magazineTier) } forEach (_magazines arrayIntersect _magazines);
    _tiers pushBack _tier;
} forEach ([_class] call A3A_fnc_getVehicleWeaponClasses);

// The default pylon loadout counts as one weapon, rated by its strongest attachment
private _pylonTier = 0;
{
    _pylonTier = _pylonTier max ([getText (_x >> "attachment")] call _fnc_magazineTier);
} forEach ("true" configClasses (_cfg >> "Components" >> "TransportPylonsComponent" >> "Pylons"));
if (_pylonTier > 0) then { _tiers pushBack _pylonTier };

_tiers sort false;
_tiers;
