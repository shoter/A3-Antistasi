/*
    Spawn vehicle near HQ for a high command squad
    Attempts to place facing into a road, otherwise fallbacks to random

Environment: Scheduled (because it's slow)

Arguments:
    1. <string> classname of vehicle to spawn
    2. unused (post-placement callback for confirmPlacement)
    3. unused (position check callback for confirmPlacement)
    4. <array> Parameters for spawning group with spawnHCGroup
    5. <array> Non-empty to create AA truck

    The road slot search lives in A3A_fnc_findHQVehicleSlot, shared with the garrison resupply trucks.
*/

#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

// Same params as HR_GRG_fnc_confirmPlacement but doesn't use the callbacks
params ["_vehType", "", "", "_groupParams", "_mounts"];

private _vehicle = createVehicle [_vehType, [0,0,-1000], [], 0, "CAN_COLLIDE"];
_vehicle enableSimulation false;

// Road slot search shared with the AI logistics runs
([_vehicle] call A3A_fnc_findHQVehicleSlot) params [["_spawnPos", false], ["_spawnDir", false]];

if (_spawnPos isEqualType false) then {
    // Random search fallback
    private _searchCenter = markerPos respawnTeamPlayer getPos [50 + random 50, random 360];
    _spawnPos = _searchCenter findEmptyPosition [0, 50, _vehType];
    if (_spawnPos isEqualTo []) then {_spawnPos = _searchCenter};
    _vehicle setVehiclePosition [_spawnPos, [], 0, "NONE"];
    _vehicle setDir random 360;
} else {
    isNil {
        _vehicle setVehiclePosition [_spawnPos, [], 0, "CAN_COLLIDE"];
        _vehicle setVectorDir _spawnDir;
    };
};
_vehicle enableSimulation true;

if (_mounts isNotEqualTo []) then {
    private _static = (FactionGet(reb,"staticAA")) # 0 createVehicle _spawnPos;
    private _nodes = [_vehicle, _static] call A3A_Logistics_fnc_canLoad;
    if (_nodes isEqualType 0) exitWith {};
    (_nodes + [true]) call A3A_Logistics_fnc_load;
    _static call HR_GRG_fnc_vehInit;
};

_groupParams + [_vehicle] spawn A3A_fnc_spawnHCGroup;
