/*
Maintainer: Shoter
    Parameter getter for the lost ammo supplies task.
    Picks a spot in the countryside within mission distance where the enemy crate came down,
    the enemy outpost or airbase that sends the recovery team, and 2-4 witness positions
    250-2000m from the crate with the bearing each of them reports (off by up to 5 degrees).

Arguments: none

Return Value:
    <BOOL> false if no valid parameters could be generated, otherwise
    <ARRAY> [weight, [crate position ATL, source marker, [[witness position ATL, reported bearing], ...]]]

Scope: Server
Environment: Any
Public: No
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

private _hqPos = markerPos "Synd_HQ";
private _players = allPlayers - entities "HeadlessClient_F";
private _minDist = 1500 min (distanceMission / 2);
private _avoidMarkers = markersX + controlsX;
private _enemySites = (outposts + airportsX + resourcesX + factories + seaports + controlsX) select { sidesX getVariable _x != teamPlayer };

private _fnc_onMap = {
    params ["_pos"];
    _pos#0 > 200 and _pos#1 > 200 and _pos#0 < worldSize - 200 and _pos#1 < worldSize - 200;
};

// Witnesses around the crate. Bearings must not line up (neither close nor opposite), or their lines can't be crossed.
private _fnc_findWitnesses = {
    params ["_cratePos"];
    private _wanted = 2 + floor random 3;
    private _witnesses = [];
    private _dirs = [];
    for "_i" from 1 to 40 do {
        if (count _witnesses >= _wanted) exitWith {};
        private _dir = random 360;
        if (_dirs findIf { private _diff = abs (_dir - _x) % 180; _diff < 30 or _diff > 150 } != -1) then { continue };

        // Sum of three randoms: 250-2000m, most witnesses around the middle of the range
        private _pos = _cratePos getPos [250 + random (1750/3) + random (1750/3) + random (1750/3), _dir];
        if !([_pos] call _fnc_onMap) then { continue };
        if (surfaceIsWater _pos) then { continue };
        if ((_pos isFlatEmpty [1, -1, 0.5, 1, 0, false, objNull]) isEqualTo []) then { continue };
        if (_enemySites inAreaArray [_pos, 300, 300] isNotEqualTo []) then { continue };
        if (_enemySites findIf { _pos inArea _x } != -1) then { continue };

        _pos set [2, 0];
        private _bearing = ((_pos getDir _cratePos) - 5 + random 10 + 360) % 360;
        _witnesses pushBack [_pos, _bearing];
        _dirs pushBack _dir;
    };
    _witnesses;
};

private _result = [];
for "_i" from 1 to 60 do {
    private _pos = _hqPos getPos [_minDist + random (distanceMission - _minDist), random 360];
    if !([_pos] call _fnc_onMap) then { continue };
    if (surfaceIsWater _pos) then { continue };

    // Open countryside: away from towns, bases, roadblocks and players, flat, not in a forest, a truck can get there
    if (_avoidMarkers inAreaArray [_pos, 600, 600] isNotEqualTo []) then { continue };
    if (_avoidMarkers findIf { _pos inArea _x } != -1) then { continue };
    if (_players inAreaArray [_pos, 1000, 1000] isNotEqualTo []) then { continue };
    if ((_pos isFlatEmpty [4, -1, 0.25, 4, 0, false, objNull]) isEqualTo []) then { continue };
    if (count nearestTerrainObjects [_pos, ["TREE", "SMALL TREE"], 25, false, true] > 4) then { continue };
    if (_pos nearRoads 500 isEqualTo []) then { continue };

    // Nearest enemy outpost or airbase that can send ground vehicles there
    private _sources = ([_pos, false] call A3A_fnc_findLandSupportMarkers) select { sidesX getVariable (_x#0) in [Occupants, Invaders] };
    if (_sources isEqualTo []) then { continue };
    private _navDists = _sources apply { _x#1 };
    private _source = _sources select (_navDists find selectMin _navDists) select 0;

    private _witnesses = [_pos] call _fnc_findWitnesses;
    if (count _witnesses < 2) then { continue };

    _pos set [2, 0];
    _result = [_pos, _source, _witnesses];
    break;
};
if (_result isEqualTo []) exitWith {false};

[1, _result];
