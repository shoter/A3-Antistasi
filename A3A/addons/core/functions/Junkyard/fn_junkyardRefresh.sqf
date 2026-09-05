/*
Maintainer: Shoter
    Replaces the junkyard stock with a fresh random selection and schedules the next delivery.
    Stock is A3A_junkyardPoolCount vehicles drawn from the civilian, rebel, occupant and invader pools,
    plus one wildcard vehicle drawn from every drivable vehicle class currently loaded.
    Statics, blacklisted garage classes and vehicles from disabled DLC are excluded.

Arguments:
    None

Return Value:
    <nil>

Scope: Server
Environment: Scheduled (config scan on first run can take a moment)
Public: No
Dependencies: HR_GRG_fnc_getCatIndex, A3A_fnc_junkyardPrice, A3A_fnc_getModOfConfigClass

Example:
    [] spawn A3A_fnc_junkyardRefresh;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

#define Reb(VAR) FactionGetOrDefault(reb, VAR, [])

if !(isServer) exitWith { Error("Attempted to call server function as non-server") };

private _fnc_valid = {
    params ["_class"];
    private _cfg = configFile >> "CfgVehicles" >> _class;
    if !(isClass _cfg) exitWith { false };
    if (_cfg call A3A_fnc_getModOfConfigClass in A3A_disabledDLC) exitWith { false };
    private _cat = [_class] call HR_GRG_fnc_getCatIndex;
    _cat >= 0 && _cat != 7;      // 7 = garage static index, -1 unsupported, -2 blacklisted
};

private _fnc_cleanPool = {
    (_this arrayIntersect _this) select { _x call _fnc_valid };
};

// Conflict pools
private _civ = (Reb("vehiclesCivCar") + Reb("vehiclesCivTruck") + Reb("vehiclesCivHeli") + Reb("vehiclesCivPlane")
    + Reb("vehiclesCivBoat") + Reb("vehiclesCivSupply") + arrayCivVeh + civBoats) call _fnc_cleanPool;
private _reb = (Reb("vehiclesBasic") + Reb("vehiclesLightUnarmed") + Reb("vehiclesTruck") + Reb("vehiclesLightArmed")
    + Reb("vehiclesMedical") + Reb("vehiclesAT") + Reb("vehiclesAA") + Reb("vehiclesBoat") + Reb("vehiclesPlane")) call _fnc_cleanPool;

private _militaryKeys = [
    "vehiclesBasic", "vehiclesTrucks", "vehiclesCargoTrucks", "vehiclesAmmoTrucks", "vehiclesRepairTrucks", "vehiclesFuelTrucks", "vehiclesMedical",
    "vehiclesLightUnarmed", "vehiclesLightArmed", "vehiclesLightAPCs", "vehiclesAPCs", "vehiclesIFVs", "vehiclesLightTanks", "vehiclesTanks", "vehiclesHeavyTanks",
    "vehiclesAA", "vehiclesSAM", "vehiclesRadar", "vehiclesArtillery", "vehiclesTransportBoats", "vehiclesGunBoats", "vehiclesAmphibious",
    "vehiclesHelisLight", "vehiclesHelisTransport", "vehiclesHelisLightAttack", "vehiclesHelisAttack",
    "vehiclesPlanesCAS", "vehiclesPlanesAA", "vehiclesPlanesTransport", "vehiclesAirPatrol",
    "vehiclesPolice", "vehiclesMilitiaCars", "vehiclesMilitiaTrucks", "vehiclesMilitiaLightArmed"
];
private _occ = [];
private _inv = [];
{
    _occ append FactionGetOrDefault(occ, _x, []);
    _inv append FactionGetOrDefault(inv, _x, []);
} forEach _militaryKeys;
_occ = _occ call _fnc_cleanPool;
_inv = _inv call _fnc_cleanPool;

private _allPoolClasses = _civ + _reb + _occ + _inv;

// Draw from the pools, weighted, no duplicates
private _pools = [[_civ, 3], [_reb, 2], [_occ, 2], [_inv, 2]];
private _stock = [];
for "_i" from 1 to A3A_junkyardPoolCount do {
    private _available = _pools select { (_x#0) isNotEqualTo [] };
    if (_available isEqualTo []) exitWith {};
    private _indices = [];
    { _indices pushBack _forEachIndex } forEach _available;
    private _pool = (_available # (_indices selectRandomWeighted (_available apply { _x#1 }))) # 0;
    private _class = _pool deleteAt (floor random count _pool);
    _stock pushBack [_class, [_class] call A3A_fnc_junkyardPrice];
};

// Wildcard: one vehicle from everything drivable that is loaded, outside the conflict pools. Scan cached per session.
if (isNil "A3A_junkyardWildcardPool") then {
    private _candidates = "getNumber (_x >> 'scope') == 2
        and {toLower getText (_x >> 'simulation') in ['carx', 'tankx', 'helicopterrtd', 'helicopterx', 'airplanex', 'shipx', 'submarinex']}
        and {getText (_x >> 'model') != ''}" configClasses (configFile >> "CfgVehicles");
    A3A_junkyardWildcardPool = (_candidates apply { configName _x }) call _fnc_cleanPool;
    Info_1("Junkyard wildcard pool built with %1 classes", count A3A_junkyardWildcardPool);
};
private _wildcards = A3A_junkyardWildcardPool - _allPoolClasses - (_stock apply { _x#0 });
if (_wildcards isNotEqualTo []) then {
    private _class = selectRandom _wildcards;
    _stock pushBack [_class, [_class] call A3A_fnc_junkyardPrice];
};

A3A_junkyardStock = _stock;
publicVariable "A3A_junkyardStock";
A3A_junkyardNextRefresh = serverTime + A3A_junkyardRefreshInterval;
publicVariable "A3A_junkyardNextRefresh";

Info_1("Junkyard restocked: %1", _stock);
[localize "STR_A3A_fn_junkyard_title", localize "STR_A3A_fn_junkyard_newStock"] remoteExec ["A3A_fnc_customHint", 0];
