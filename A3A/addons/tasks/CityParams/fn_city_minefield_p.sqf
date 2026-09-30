/*
    Params getter for the minefield clearing city task
    Looks for a patch of open ground on the edge of the town, away from roads, buildings, players and other mines

Maintainer: Shoter

Arguments:
    <STRING> City marker

Return Value:
    <ARRAY> [marker, field centre, field radius, mine count] or false if no place was found
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

params ["_marker"];

private _markerPos = markerPos _marker;
private _townRad = 500 min vectorMagnitude markerSize _marker;
private _players = call A3A_fnc_playableUnits;

private _fieldPos = false;
for "_i" from 1 to 20 do {
    private _pos = _markerPos getPos [_townRad * 0.5 + random (_townRad * 0.5 + 150), random 360];
    _pos set [2, 0];
    if (surfaceIsWater _pos) then { continue };
    if (_pos nearRoads 25 isNotEqualTo []) then { continue };               // civilians drive there
    if (nearestTerrainObjects [_pos, ["BUILDING", "HOUSE", "CHURCH", "CHAPEL", "FUELSTATION", "HOSPITAL", "RUIN", "WALL"], 20, false, true] isNotEqualTo []) then { continue };
    if (nearestObjects [_pos, ["House"], 20] isNotEqualTo []) then { continue };
    if (_players inAreaArray [_pos, 150, 150] isNotEqualTo []) then { continue };
    if (allUnits inAreaArray [_pos, 30, 30] isNotEqualTo []) then { continue };
    if (allMines inAreaArray [_pos, 100, 100] isNotEqualTo []) then { continue };
    _fieldPos = _pos;
    break;
};
if (_fieldPos isEqualType false) exitWith {
    Debug_1("Found no open ground for a minefield in %1", _marker);
    false;
};

// Field radius 5-10 m, roughly one mine per metre of radius
private _fieldRad = 5 + random 5;
private _mineCount = round _fieldRad;

[_marker, _fieldPos, _fieldRad, _mineCount];
