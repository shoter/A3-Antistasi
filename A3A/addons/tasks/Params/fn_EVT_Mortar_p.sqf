/*
Maintainer: Shoter
    Parameter getter for the enemy mortar fire event.
    Picks a rebel place (town on our side, any rebel-held site or the HQ), an enemy outpost or airbase,
    and a mortar position 1-2 km from the rebel place and 1-3 km from the enemy base, on dry, fairly
    flat ground that the mortar team can walk to from the base without crossing water.
    Only one mortar fire event runs at a time.

Arguments: none

Return Value:
    <BOOL> false if no valid parameters could be generated, otherwise
    <ARRAY> [weight, [target marker, enemy base marker, mortar position ATL, enemy side]]

Scope: Server
Environment: Scheduled
Public: No
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

#define TARGET_MIN 1000
#define TARGET_MAX 2000
#define BASE_MIN 1000
#define BASE_MAX 3000

if ("MORTAR" in A3A_activeTasks) exitWith {false};

private _targets = (citiesX + outposts + airportsX + resourcesX + factories + seaports + outpostsFIA) select {
    sidesX getVariable [_x, sideUnknown] == teamPlayer
};
if (!(missionNamespace getVariable ["A3A_petrosMoving", false])) then { _targets pushBack "Synd_HQ" };

private _bases = (outposts + airportsX) select { sidesX getVariable [_x, sideUnknown] in [Occupants, Invaders] };
if (_targets isEqualTo [] or _bases isEqualTo []) exitWith {false};

private _rebelMarkers = (markersX + outpostsFIA) select { sidesX getVariable [_x, sideUnknown] == teamPlayer };

// Good spot for the mortar, and a walk from the base without water on the way
private _fnc_mortarSpot = {
    params ["_pos", "_basePos"];
    if (surfaceIsWater _pos) exitWith {false};
    if ((surfaceNormal _pos) # 2 < 0.93) exitWith {false};
    if (_rebelMarkers findIf { markerPos _x distance2d _pos < 600 } != -1) exitWith {false};
    if (markerPos "Synd_HQ" distance2d _pos < TARGET_MIN) exitWith {false};
    private _dist = _basePos distance2d _pos;
    private _dir = _basePos getDir _pos;
    private _steps = floor (_dist / 100);
    private _wet = false;
    for "_i" from 1 to _steps do {
        if (surfaceIsWater (_basePos getPos [_i * 100, _dir])) exitWith { _wet = true };
    };
    !_wet;
};

private _result = false;
{
    private _target = _x;
    private _targetPos = markerPos _target;
    private _nearBases = _bases select { markerPos _x distance2d _targetPos < TARGET_MAX + BASE_MAX };
    {
        private _base = _x;
        private _basePos = markerPos _base;
        for "_i" from 1 to 15 do {
            private _pos = _targetPos getPos [TARGET_MIN + random (TARGET_MAX - TARGET_MIN), random 360];
            private _baseDist = _pos distance2d _basePos;
            if (_baseDist < BASE_MIN or _baseDist > BASE_MAX) then { continue };
            if !([_pos, _basePos] call _fnc_mortarSpot) then { continue };
            _result = [1, [_target, _base, [_pos # 0, _pos # 1, 0], sidesX getVariable _base]];
            break;
        };
        if (_result isEqualType []) then { break };
    } forEach (_nearBases call BIS_fnc_arrayShuffle);
    if (_result isEqualType []) then { break };
} forEach (_targets call BIS_fnc_arrayShuffle);

_result;
