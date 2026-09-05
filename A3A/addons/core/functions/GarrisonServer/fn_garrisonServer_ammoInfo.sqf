/*
Maintainer: Shoter
    Ammo and crew readout of the armed vehicles in a rebel garrison, for the Garrisons tab and the garrison
    management tab. Spawned sites are read from the live objects, despawned sites from the state stored on despawn.
    Only counts leave the server, the garrison hashmap itself stays here.

Arguments:
    <STRING> Marker name of the garrison
    <BOOL> True to list only static weapons, false for every vehicle with turret magazines [DEFAULT = true]

Return Value:
    <ARRAY> [[vehID, class, ammoFraction, crewState], ...]
        ammoFraction: 0..1 of the default loadout
        crewState: -1 site despawned, 0 nobody in the gunner seat, 1 AI gunner, 2 player gunner

Scope: Server
Environment: Any
Public: No
Dependencies:
    A3A_garrison, spawner, A3A_fnc_getAmmoFraction, A3A_fnc_garrisonServer_findVehicle

Example:
    [_marker] call A3A_fnc_garrisonServer_ammoInfo;
    [_marker, false] call A3A_fnc_garrisonServer_ammoInfo;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_marker", "", [""]], ["_staticsOnly", true, [true]]];

private _garrison = A3A_garrison getOrDefault [_marker, createHashMap];
private _spawned = spawner getVariable [_marker, 2] != 2;
private _info = [];
{
    _x params ["_class", "", "", ["_vehID", -1]];
    if (_staticsOnly && { !(_class isKindOf "StaticWeapon") }) then { continue };
    private _state = if (isNil { _x # 2 }) then { [] } else { _x # 2 };      // nil until the first despawn

    private _veh = if (_spawned) then { [_marker, _x] call A3A_fnc_garrisonServer_findVehicle } else { objNull };
    private _fraction = if (isNull _veh) then {
        [_class, _state] call A3A_fnc_getAmmoFraction
    } else {
        [_veh] call A3A_fnc_getAmmoFraction
    };
    if (_fraction < 0) then { continue };          // nothing to rearm on this one

    private _crewState = call {
        if (!_spawned) exitWith { -1 };
        if (isNull _veh) exitWith { 0 };
        private _gunner = gunner _veh;
        if (isNull _gunner) exitWith { 0 };
        if (isPlayer _gunner) exitWith { 2 };
        1
    };
    _info pushBack [_vehID, _class, _fraction, _crewState];
} forEach (_garrison getOrDefault ["vehicles", []]);

_info
