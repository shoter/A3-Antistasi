/*
    Server-side function to clean up off-faction vehicles from unspawned enemy or civ garrisons
    Also refunds any excess troops

    Environment: Unscheduled or init, server

    Arguments:
    <STRING> Marker name or spawn key of garrison.
    <BOOL> True if called to sanity-check saves. Doesn't currently make a difference.
    <BOOL> True for only cleanup excess troops, not vehicles.

    Copyright 2025 John Jordan. All Rights Reserved.
    Used and distributed by the Antistasi Community project with permission.
*/

// side needs to be correct when called
// initVarServer must be complete, and enemy resources must be set

#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

Trace_1("Called with params %1", _this);

params ["_marker", "_fromSave", "_troopsOnly"];

private _garrison = A3A_garrison get _marker;

if ("_civ" in _marker) exitWith
{
    private _places = A3A_spawnPlacesHM get _marker;
    private _valid = A3A_validVehicles get civilian;
    private _vehicles = _garrison get "vehicles";
    {
        _x params ["_vehType", "_slotNum"];

        // Shouldn't trigger now that save is checked
        if (_slotNum isEqualType 0 and { _slotNum >= count _places }) then {
            Error_1("Slot number above slot count for %1 in %2", _x, _marker);
            _vehicles deleteAt _forEachIndex;
            continue;
        };

        // Temporary fix for boats being mangled in 3.10.3
        // Incorrect since boat format changed
//        while {_slotNum isEqualType [] and {_slotNum#0 isEqualType []}} do {
//            Error_3("Fixing incorrect boat format for %1, pos %2, dir %3", _vehType, _slotNum#0, _slotNum#1);
//            _x set [2, _slotNum#1]; _x set [1, _slotNum#0]; _slotNum = _x#1;
//        };

        private _slotType = if (_slotNum isEqualType []) then { "civBoat" } else { _places # _slotNum # 0 };
        if !(_vehType in (_valid get _slotType)) then {
            Debug_2("%1 (slot type %2) not valid, swapping", _vehType, _slotType);
            if (_slotType == "civCar") exitWith { _x set [0, selectRandomWeighted civVehiclesWeighted] };
            if (_slotType == "civBoat") exitWith { _x set [0, selectRandomWeighted civBoatsWeighted] };
            _vehicles deleteAt _forEachIndex;       // vehiclePolice case
        };
    } forEachReversed (_garrison get "vehicles");
};

private _side = sidesX getVariable _marker;
if (_side == teamPlayer) exitWith {};           // nothing to do here at the moment. TODO: Could use to set threat for unknown vehicles on init?

// Refund any excess troops. Troops that joined from a won attack (extraTroops) are allowed above the garrison size
private _troops = _garrison get "troops";
private _garrisonSize = A3A_garrisonSize get _marker;
private _excess = (_troops#0) - (_garrisonSize + (_garrison getOrDefault ["extraTroops", 0]));
if (_excess > 0) then {
    Debug_2("Clearing %1 excess troops in %2", _excess, _marker);
    _troops set [0, _troops#0 - _excess];
    if (_garrison get "type" != "city") then { [10*_excess, _side, "defence"] call A3A_fnc_addEnemyResources };
};
// The allowance shrinks as those troops die, so it never gets refilled
private _extraTroops = 0 max ((_troops#0) - _garrisonSize);
if (_extraTroops > 0) then { _garrison set ["extraTroops", _extraTroops] } else { _garrison deleteAt "extraTroops" };

if (_troopsOnly) exitWith { Trace("Completed") };

// each static & vehicle:
// - lookup type using place index
// - if it doesn't have a place index then just refund it
// - check if type is valid for faction
// - if not, swap for valid vehicle

private _faction = Faction(_side);
private _places = A3A_spawnPlacesHM get _marker;
private _valid = A3A_validVehicles get _side;
private _isAirport = _marker in airportsX;

private _usedSlots = [];
private _vehicles = _garrison get "vehicles";
private _joinedPositions = _garrison getOrDefault ["joinedPositions", []];
{
    _x params ["_vehType", "_slotNum", "", "_vehID"];

    // Vehicle that joined from a won attack keeps its own position
    if (_slotNum isEqualType [] and { private _pos = _slotNum#0; _joinedPositions findIf { _x distance _pos < 0.5 } != -1 }) then { continue };

    if (_slotNum isEqualType [] or { _slotNum >= count _places }) then {
        _vehicles deleteAt _forEachIndex;
        private _cost = A3A_vehicleResourceCosts getOrDefault [_vehType, 0];
        [_cost, _side, "defence"] call A3A_fnc_addEnemyResources;
        Debug_1("Refunding %1", _vehType);
        continue;
    };

    // Temporary code to clean up 3.10.3 reinf bugs
    if (_slotNum in _usedSlots) then {
        _vehicles deleteAt _forEachIndex;
        (_garrison get "supportVehicles") deleteAt _vehID;
        Debug_2("Clearing excess vehicle %1 in slot %2", _vehType, _slotNum);
    };
    _usedSlots pushBack _slotNum;

    private _slotType = _places # _slotNum # 0;
    if !(_vehType in (_valid get _slotType)) then {
        // Arguably should refund this case if it's not a save?
        _x set [0, [_faction, _slotType, _isAirport] call A3A_fnc_selectGarrisonVehicleType];
        if (_x#0 in A3A_supportVehTypes) then {
            (_garrison get "supportVehicles") set [_vehID, ["ready", A3A_supportVehTypes get _x#0, _x]];
        } else {
            (_garrison get "supportVehicles") deleteAt _vehID;
        };
        Debug_3("%1 (slot type %2) not valid, swapping to %3", _vehType, _slotType, _x#0);
    };
} forEachReversed _vehicles;

// Forget joined-vehicle marks whose vehicle is gone
if ("joinedSlots" in _garrison) then {
    private _slots = _vehicles select { _x#1 isEqualType 0 } apply { _x#1 };
    _garrison set ["joinedSlots", (_garrison get "joinedSlots") arrayIntersect _slots];
};
if ("joinedPositions" in _garrison) then {
    private _positions = _vehicles select { _x#1 isEqualType [] } apply { _x#1#0 };
    _garrison set ["joinedPositions", _joinedPositions select { private _pos = _x; _positions findIf { _x distance _pos < 0.5 } != -1 }];
};
