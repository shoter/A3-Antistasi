/*
Maintainer: Shoter
    Server-side function to add a live vehicle from a won attack to an enemy garrison
    Takes a free vehicle parking place if the type fits one, otherwise keeps the vehicle's own position.
    Marks the vehicle so that it respawns with a full crew and survives the cleanup of off-place vehicles.

    Environment: Unscheduled, server

    Arguments:
    <STRING> Marker name of garrison.
    <OBJECT> Vehicle to add to garrison.
*/

#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params ["_marker", "_vehicle"];
private _vehType = typeOf _vehicle;

Trace_1("Called with params %1", _this);

private _side = sidesX getVariable _marker;
if (_side == teamPlayer) exitWith {
    Error_1("Attempted to add joined vehicle to rebel garrison %1", _marker);
};

// The garrison owns the vehicle now
private _despawnerHandle = _vehicle getVariable "A3A_despawnerHandle";
if (!isNil "_despawnerHandle") then { terminate _despawnerHandle; _vehicle setVariable ["A3A_despawnerHandle", nil] };

private _garrison = A3A_garrison get _marker;

// Free vehicle parking place, if the type is allowed there
private _slotNum = -1;
if (_vehType in (A3A_validVehicles get _side get "vehicle")) then {
    private _usedPlaces = (_garrison get "vehicles") select {_x#1 isEqualType 0} apply {_x#1};
    private _places = (A3A_spawnPlaceStats getOrDefault [_marker, createHashMap]) getOrDefault ["vehicle", [[]]] select 0;
    _places = _places - _usedPlaces;
    if (_places isNotEqualTo []) then { _slotNum = _places#0 };
};

// Records the current position, and deletes the vehicle if the garrison is despawned
private _vehID = _garrison get "nextVehID";
[_marker, _vehicle] call A3A_fnc_garrisonServer_addVehicle;

private _index = (_garrison get "vehicles") findIf { _x#3 == _vehID };
if (_index == -1) exitWith {
    Error_2("Joined vehicle %1 not found in garrison %2", _vehType, _marker);
};
private _vehEntry = (_garrison get "vehicles") # _index;

if (_slotNum >= 0) then {
    _vehEntry set [1, _slotNum];
    (_garrison getOrDefault ["joinedSlots", [], true]) pushBack _slotNum;
} else {
    (_garrison getOrDefault ["joinedPositions", [], true]) pushBack (_vehEntry#1#0);
};

Debug_3("Joined vehicle %1 added to %2, place %3", _vehType, _marker, _vehEntry#1);
