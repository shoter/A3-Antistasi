/*
Maintainer: Shoter
    Estimates how long a vehicle delivery takes from its origin site to the destination.
    Single source of truth for the client preview and the server hint. The real route follows
    the roads, so the straight distance is stretched by a detour factor.

Arguments:
    <POSITION> Origin position
    <POSITION> Destination position

Return Value:
    <NUMBER> Estimated seconds until the vehicle arrives

Scope: Any
Environment: Any
Public: Yes
Dependencies:

Example:
    [markerPos "outpost_3", getPosATL player] call A3A_fnc_deliverVehicleEta;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

// Average road speed in metres per second and the detour factor of roads over the straight line
#define DELIVERY_ETA_SPEED 9
#define DELIVERY_ROAD_FACTOR 1.4

params [["_originPos", [0,0,0], [[]]], ["_destPos", [0,0,0], [[]]]];

round ((_originPos distance2D _destPos) * DELIVERY_ROAD_FACTOR / DELIVERY_ETA_SPEED + 30)
