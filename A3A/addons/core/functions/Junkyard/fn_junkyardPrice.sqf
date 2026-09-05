/*
Maintainer: Shoter
    Junkyard price of a wrecked vehicle. Tier table by faction category, with a fallback by vehicle kind
    for classes that belong to no faction in the conflict. Adds a small random jitter and rounds.
    Tune the numbers in this file only. Civilian tiers are priced at 3x and everything else at 2x of the original table.

Arguments:
    <STRING> Vehicle class name

Return Value:
    <SCALAR> Price in €, 0 if the class does not exist

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
    [Reb("vehiclesCivCar") + arrayCivVeh, 300],
    [Reb("vehiclesCivBoat") + civBoats, 450],
    [Reb("vehiclesCivTruck") + Reb("vehiclesCivSupply"), 600],
    [Reb("vehiclesCivHeli"), 10500],
    [Reb("vehiclesCivPlane"), 15000],

    [Reb("vehiclesBasic"), 400],
    [Reb("vehiclesLightUnarmed"), 800],
    [Reb("vehiclesTruck"), 1200],
    [Reb("vehiclesBoat"), 1600],
    [Reb("vehiclesMedical"), 3000],
    [Reb("vehiclesLightArmed") + Reb("vehiclesAT"), 5000],
    [Reb("vehiclesAA"), 6000],
    [Reb("vehiclesPlane"), 10000],

    [OccAndInv("vehiclesPolice") + OccAndInv("vehiclesMilitiaCars") + OccAndInv("vehiclesBasic"), 600],
    [OccAndInv("vehiclesLightUnarmed"), 800],
    [OccAndInv("vehiclesMilitiaTrucks"), 1000],
    [OccAndInv("vehiclesTrucks"), 1200],
    [OccAndInv("vehiclesCargoTrucks") + OccAndInv("vehiclesTransportBoats"), 1600],
    [OccAndInv("vehiclesAmmoTrucks") + OccAndInv("vehiclesRepairTrucks") + OccAndInv("vehiclesFuelTrucks") + OccAndInv("vehiclesMedical"), 3000],
    [OccAndInv("vehiclesMilitiaLightArmed"), 4000],
    [OccAndInv("vehiclesLightArmed"), 5000],
    [OccAndInv("vehiclesGunBoats"), 6000],

    // Military ground vehicles: up to 20000 after jitter, except tanks, artillery and heavy tanks which go up to 40000
    [OccAndInv("vehiclesLightAPCs"), 5000],
    [OccAndInv("vehiclesAPCs") + OccAndInv("vehiclesAmphibious") + OccAndInv("vehiclesRadar"), 8000],
    [OccAndInv("vehiclesIFVs"), 11000],
    [OccAndInv("vehiclesLightTanks"), 12000],
    [OccAndInv("vehiclesAA"), 14000],
    [OccAndInv("vehiclesSAM"), 17000],
    [OccAndInv("vehiclesTanks") + OccAndInv("vehiclesArtillery"), 24000],
    [OccAndInv("vehiclesHeavyTanks"), 34000],

    // Air
    [OccAndInv("vehiclesHelisLight"), 16000],
    [OccAndInv("vehiclesHelisTransport"), 30000],
    [OccAndInv("vehiclesAirPatrol"), 40000],
    [OccAndInv("vehiclesHelisLightAttack"), 50000],
    [OccAndInv("vehiclesPlanesTransport"), 60000],
    [OccAndInv("vehiclesHelisAttack"), 110000],
    [OccAndInv("vehiclesPlanesCAS"), 160000],
    [OccAndInv("vehiclesPlanesAA"), 200000]
];

private _base = -1;
{
    if (_class in (_x#0)) exitWith { _base = _x#1 };
} forEach _tiers;

// Fallback for vehicles outside the conflict factions (junkyard wildcard): by kind and armament
if (_base == -1) then {
    private _armed = ([_class] call A3A_fnc_getVehicleWeapons) isNotEqualTo [];
    _base = call {
        if (getNumber (_cfg >> "isUav") > 0) exitWith { 10000 };
        if (_class isKindOf "Tank") exitWith { 24000 };
        if (_class isKindOf "Wheeled_APC_F" or _class isKindOf "Tracked_APC") exitWith { 9000 };
        if (_class isKindOf "Helicopter") exitWith { [20000, 80000] select _armed };
        if (_class isKindOf "Plane") exitWith { [60000, 160000] select _armed };
        if (_class isKindOf "Ship") exitWith { [1600, 6000] select _armed };
        if (_class isKindOf "Car") exitWith { [1000, 5000] select _armed };
        2000;
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
