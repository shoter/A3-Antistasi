/*
Maintainer: Shoter
    Junkyard price of a wrecked vehicle. Tier table by faction category, with a fallback by vehicle kind
    for classes that belong to no faction in the conflict. Adds a small random jitter and rounds.
    Tune the numbers in this file only.

Arguments:
    <STRING> Vehicle class name

Return Value:
    <SCALAR> Price in PLN, 0 if the class does not exist

Scope: Anywhere (faction hashmaps and civilian lists are broadcast)
Environment: Any
Public: Yes
Dependencies:

Example:
    ["O_MBT_02_cannon_F"] call A3A_fnc_junkyardPrice;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

#define OccAndInv(VAR) (FactionGetOrDefault(occ, VAR, []) + FactionGetOrDefault(inv, VAR, []))
#define Reb(VAR) FactionGetOrDefault(reb, VAR, [])

params [["_class", "", [""]]];
private _cfg = configFile >> "CfgVehicles" >> _class;
if !(isClass _cfg) exitWith { 0 };

// [classes, base price]. First match wins, so civilian tiers come first.
private _tiers = [
    [Reb("vehiclesCivCar") + arrayCivVeh, 100],
    [Reb("vehiclesCivBoat") + civBoats, 150],
    [Reb("vehiclesCivTruck") + Reb("vehiclesCivSupply"), 200],
    [Reb("vehiclesCivHeli"), 3500],
    [Reb("vehiclesCivPlane"), 5000],

    [Reb("vehiclesBasic"), 200],
    [Reb("vehiclesLightUnarmed"), 400],
    [Reb("vehiclesTruck"), 600],
    [Reb("vehiclesBoat"), 800],
    [Reb("vehiclesMedical"), 1500],
    [Reb("vehiclesLightArmed") + Reb("vehiclesAT"), 2500],
    [Reb("vehiclesAA"), 3000],
    [Reb("vehiclesPlane"), 5000],

    [OccAndInv("vehiclesPolice") + OccAndInv("vehiclesMilitiaCars") + OccAndInv("vehiclesBasic"), 300],
    [OccAndInv("vehiclesLightUnarmed"), 400],
    [OccAndInv("vehiclesMilitiaTrucks"), 500],
    [OccAndInv("vehiclesTrucks"), 600],
    [OccAndInv("vehiclesCargoTrucks") + OccAndInv("vehiclesTransportBoats"), 800],
    [OccAndInv("vehiclesAmmoTrucks") + OccAndInv("vehiclesRepairTrucks") + OccAndInv("vehiclesFuelTrucks") + OccAndInv("vehiclesMedical"), 1500],
    [OccAndInv("vehiclesMilitiaLightArmed"), 2000],
    [OccAndInv("vehiclesLightArmed"), 2500],
    [OccAndInv("vehiclesGunBoats"), 3000],

    // Military ground vehicles: up to 10000 after jitter, except tanks, artillery and heavy tanks which go up to 20000
    [OccAndInv("vehiclesLightAPCs"), 2500],
    [OccAndInv("vehiclesAPCs") + OccAndInv("vehiclesAmphibious") + OccAndInv("vehiclesRadar"), 4000],
    [OccAndInv("vehiclesIFVs"), 5500],
    [OccAndInv("vehiclesLightTanks"), 6000],
    [OccAndInv("vehiclesAA"), 7000],
    [OccAndInv("vehiclesSAM"), 8500],
    [OccAndInv("vehiclesTanks") + OccAndInv("vehiclesArtillery"), 12000],
    [OccAndInv("vehiclesHeavyTanks"), 17000],

    // Air
    [OccAndInv("vehiclesHelisLight"), 8000],
    [OccAndInv("vehiclesHelisTransport"), 15000],
    [OccAndInv("vehiclesAirPatrol"), 20000],
    [OccAndInv("vehiclesHelisLightAttack"), 25000],
    [OccAndInv("vehiclesPlanesTransport"), 30000],
    [OccAndInv("vehiclesHelisAttack"), 55000],
    [OccAndInv("vehiclesPlanesCAS"), 80000],
    [OccAndInv("vehiclesPlanesAA"), 100000]
];

private _base = -1;
{
    if (_class in (_x#0)) exitWith { _base = _x#1 };
} forEach _tiers;

// Fallback for vehicles outside the conflict factions (junkyard wildcard): by kind and armament
if (_base == -1) then {
    private _armed = ([_class] call A3A_fnc_getVehicleWeapons) isNotEqualTo [];
    _base = call {
        if (getNumber (_cfg >> "isUav") > 0) exitWith { 5000 };
        if (_class isKindOf "Tank") exitWith { 12000 };
        if (_class isKindOf "Wheeled_APC_F" or _class isKindOf "Tracked_APC") exitWith { 4500 };
        if (_class isKindOf "Helicopter") exitWith { [10000, 40000] select _armed };
        if (_class isKindOf "Plane") exitWith { [30000, 80000] select _armed };
        if (_class isKindOf "Ship") exitWith { [800, 3000] select _armed };
        if (_class isKindOf "Car") exitWith { [500, 2500] select _armed };
        1000;
    };
};

// Jitter and rounding, same brackets as the gun shop
private _price = _base * (0.85 + random 0.3);
_price = call {
    if (_price > 2000) exitWith { ceil (_price / 100) * 100 };
    if (_price > 200) exitWith { ceil (_price / 10) * 10 };
    ceil _price;
};
_price max 50;
