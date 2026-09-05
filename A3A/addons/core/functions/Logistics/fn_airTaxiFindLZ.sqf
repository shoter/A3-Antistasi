/*
Maintainer: Shoter
    Finds a helicopter landing zone around a position, searching in expanding rings.
    Uses BIS_fnc_findSafePos like the enemy QRF landings, with A3A_fnc_findEmptyPos as a fallback.

Arguments:
    <POSITION> Centre of the search
    <BOOL> Reject zones with enemies in combat nearby (A3A_fnc_enemyNearCheck) [DEFAULT = true]
    <ARRAY<POSITION>> Positions to stay at least 30 m away from [DEFAULT = []]
    <ARRAY<ARRAY>> Search rings as [minDistance, maxDistance] pairs, tried in order [DEFAULT = [[0,150],[150,300],[300,500]]]

Return Value:
    <POSITION> Landing position (ATL, z = 0) or [] when nothing was found

Scope: Server
Environment: Any
Public: No
Dependencies:

Example:
    [getPosATL player] call A3A_fnc_airTaxiFindLZ;
    [markerPos "outpost_1", false, [_oldLZ], [[50,150],[150,300]]] call A3A_fnc_airTaxiFindLZ;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [
    ["_centre", [0,0,0], [[]]],
    ["_checkEnemies", true, [false]],
    ["_blacklist", [], [[]]],
    ["_rings", [[0,150],[150,300],[300,500]], [[]]]
];

private _fnc_valid = {
    params ["_pos"];
    if (_pos isEqualTo [] || { _pos isEqualTo [0,0,0] } || { _pos isEqualTo [0,0] }) exitWith { false };
    if (surfaceIsWater _pos) exitWith { false };
    if (_blacklist findIf { _x distance2D _pos < 30 } != -1) exitWith { false };
    if (_checkEnemies && { [_pos] call A3A_fnc_enemyNearCheck }) exitWith { false };
    true
};

private _result = [];
{
    _x params ["_min", "_max"];
    private _pos = [_centre, _min, _max, 10, 0, 0.12, 0, [], [[0,0,0],[0,0,0]]] call BIS_fnc_findSafePos;
    if ([_pos] call _fnc_valid) exitWith { _result = [_pos#0, _pos#1, 0] };
    _pos = [_centre, _min, _max, 12, 30] call A3A_fnc_findEmptyPos;
    if ([_pos] call _fnc_valid) exitWith { _result = [_pos#0, _pos#1, 0] };
} forEach _rings;

Debug_3("Air taxi LZ search around %1 (enemy check %2): %3", _centre, _checkEnemies, _result);
_result
