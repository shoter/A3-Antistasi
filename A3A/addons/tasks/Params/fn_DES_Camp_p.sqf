/*
Maintainer: Shoter
    Parameter getter for the enemy camp task.
    Picks a spot out in the woods within mission distance of HQ: away from towns, bases, roads,
    buildings and players, on flat ground with enough trees around it. On maps without much
    forest it settles for any quiet spot in the countryside.
    The camp belongs to the side holding the nearest military site.

Arguments: none

Return Value:
    <BOOL> false if no valid parameters could be generated, otherwise
    <ARRAY> [weight, [camp position ATL, enemy side]]

Scope: Server
Environment: Scheduled
Public: No
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

private _hqPos = markerPos "Synd_HQ";
private _players = call A3A_fnc_playableUnits;
private _avoidMarkers = markersX + controlsX + outpostsFIA;
private _militaryMarkers = airportsX + outposts + seaports + resourcesX + factories;

// Clear, flat ground where the camp fits. Trees and bushes right at the spot are hidden by the task
private _fnc_campSpot = {
    params ["_pos", "_minTrees"];
    if (surfaceIsWater _pos) exitWith {false};
    if (_pos distance2d _hqPos < 800 or _pos distance2d _hqPos > distanceMission) exitWith {false};
    if (_avoidMarkers findIf { markerPos _x distance2d _pos < 800 } != -1) exitWith {false};
    if (_players inAreaArray [_pos, 800, 800] isNotEqualTo []) exitWith {false};
    if (_pos nearRoads 120 isNotEqualTo []) exitWith {false};
    if (nearestTerrainObjects [_pos, ["HOUSE", "BUILDING", "CHURCH", "CHAPEL", "RUIN", "BUNKER", "FORTRESS", "LIGHTHOUSE", "FUELSTATION", "HOSPITAL", "TRANSMITTER", "POWERSOLAR", "POWERWIND", "WATERTOWER", "QUAY", "VIEW-TOWER"], 150, false, true] isNotEqualTo []) exitWith {false};
    if (nearestTerrainObjects [_pos, ["ROCK", "ROCKS", "WALL", "FENCE", "HIDE", "MAIN ROAD", "ROAD", "TRACK", "TRAIL"], 17, false, true] isNotEqualTo []) exitWith {false};
    // Flat enough for tents: the centre, the tent ring and the supply corner further out
    if ((surfaceNormal _pos) # 2 < 0.96) exitWith {false};
    if ([0, 45, 90, 135, 180, 225, 270, 315] findIf {
        (surfaceNormal (_pos getPos [9, _x])) # 2 < 0.94 or (surfaceNormal (_pos getPos [13, _x])) # 2 < 0.92 or surfaceIsWater (_pos getPos [16, _x])
    } != -1) exitWith {false};
    count nearestTerrainObjects [_pos, ["TREE"], 60, false, true] >= _minTrees;
};

private _campPos = [];
{
    _x params ["_expression", "_minTrees"];
    for "_i" from 1 to 30 do {
        private _center = _hqPos getPos [800 + random (distanceMission - 800), random 360];
        if (surfaceIsWater _center) then { continue };
        private _places = selectBestPlaces [_center, 500, _expression, 40, 6];
        {
            private _placePos = _x # 0;
            // Look for a small clearing next to the spot
            for "_j" from 1 to 6 do {
                private _testPos = if (_j == 1) then { _placePos } else { _placePos getPos [5 + random 35, random 360] };
                if ([_testPos, _minTrees] call _fnc_campSpot) exitWith { _campPos = _testPos };
            };
            if (_campPos isNotEqualTo []) exitWith {};
        } forEach _places;
        if (_campPos isNotEqualTo []) exitWith {};
    };
    if (_campPos isNotEqualTo []) exitWith {};
} forEach [
    ["forest + trees - 3*houses - 10*sea", 20],         // in the woods
    ["meadow + trees - 3*houses - 10*sea", 3]           // countryside fallback for open maps
];

if (_campPos isEqualTo []) exitWith {false};
_campPos = [_campPos # 0, _campPos # 1, 0];

private _enemyMarkers = _militaryMarkers select { sidesX getVariable [_x, sideUnknown] in [Occupants, Invaders] };
private _side = Occupants;
if (_enemyMarkers isNotEqualTo []) then {
    _side = sidesX getVariable ([_enemyMarkers, _campPos] call BIS_fnc_nearestPosition);
};

[1, [_campPos, _side]];
