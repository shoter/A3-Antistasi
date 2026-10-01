/*
Maintainer: Shoter
    Lists the rebel sites a vehicle delivery can start from: the HQ, rebel-held outposts and rebel-held airports.
    The HQ is listed as "Synd_HQ" and left out while it is being moved.
    Optionally sorted by distance to a position, nearest first.

Arguments:
    <POSITION> Position to sort by (optional, unsorted when omitted)

Return Value:
    <ARRAY<STRING>> Origin site markers

Scope: Any
Environment: Any
Public: Yes
Dependencies:
    <ARRAY> outposts, airportsX
    <OBJECT> sidesX
    <BOOL> A3A_petrosMoving

Example:
    [getPosATL player] call A3A_fnc_deliverVehicleOrigins;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_sortPos", [], [[]]]];

private _origins = (outposts + airportsX) select { sidesX getVariable [_x, sideUnknown] == teamPlayer };
if !(missionNamespace getVariable ["A3A_petrosMoving", false]) then { _origins pushBack "Synd_HQ" };

if (_sortPos isNotEqualTo []) then {
    _origins = _origins apply { [markerPos _x distance2D _sortPos, _x] };
    _origins sort true;
    _origins = _origins apply { _x # 1 };
};
_origins
