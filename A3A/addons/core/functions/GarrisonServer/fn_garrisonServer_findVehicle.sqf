/*
Maintainer: Shoter
    Finds the live object of a garrison vehicle entry.
    The garrison data only stores class, position and vehicle ID, so the object is looked up by position
    and confirmed with its A3A_vehID. Works for vehicles spawned on any machine, objects are global.
    Does not check whether the site is spawned: despawn calls this while the objects still exist.

Arguments:
    <STRING> Marker name of the garrison
    <ARRAY> Vehicle entry [class, posData, state, vehID] from the garrison "vehicles" array

Return Value:
    <OBJECT> The live vehicle, objNull when it is missing, dead or carries another vehicle ID

Scope: Server
Environment: Any
Public: No
Dependencies:
    A3A_spawnPlacesHM, spawner

Example:
    [_marker, _vehEntry] call A3A_fnc_garrisonServer_findVehicle;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_marker", "", [""]], ["_vehEntry", [], [[]]]];
if (_marker == "" || { _vehEntry isEqualTo [] }) exitWith { objNull };

_vehEntry params ["_class", "_posData", "", ["_vehID", -1]];

// Predefined spawn place index (enemy-style placement) or an explicit [posWorld, vecDir, vecUp]
private _posATL = if (_posData isEqualType 0) then {
    private _spawnPlaces = A3A_spawnPlacesHM getOrDefault [_marker, []];
    if (_posData >= count _spawnPlaces) exitWith { [] };
    _spawnPlaces # _posData # 1
} else {
    ASLtoATL (_posData # 0)
};
if (_posATL isEqualTo []) exitWith { objNull };

private _veh = nearestObject [_posATL, _class];
if (isNull _veh || { !alive _veh }) exitWith { objNull };
if (_vehID != _veh getVariable ["A3A_vehID", -1]) exitWith { objNull };
_veh
