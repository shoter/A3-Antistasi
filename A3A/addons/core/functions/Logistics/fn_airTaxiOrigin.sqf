/*
Maintainer: Shoter
    Picks the base an air taxi is dispatched from: the friendly airbase or the HQ nearest to a position.

Arguments:
    <POSITION> Position to serve (usually the pickup landing zone)

Return Value:
    <STRING> Marker name of the origin (an airport marker or respawnTeamPlayer)

Scope: Any
Environment: Any
Public: Yes
Dependencies:
    <ARRAY> airportsX
    <OBJECT> sidesX
    <STRING> respawnTeamPlayer

Example:
    [getPosATL player] call A3A_fnc_airTaxiOrigin;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_pos", [0,0,0], [[]]]];

private _bases = (airportsX select { sidesX getVariable [_x, sideUnknown] == teamPlayer }) + [respawnTeamPlayer];
[_bases, _pos] call BIS_fnc_nearestPosition
