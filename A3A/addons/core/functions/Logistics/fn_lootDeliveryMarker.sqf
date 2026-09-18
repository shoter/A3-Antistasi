/*
Maintainer: Shoter
    Creates the map marker that follows a loot crate delivery vehicle and refreshes its position
    every 10 seconds until the marker is deleted or the vehicle is gone.

Arguments:
    <ARRAY> Delivery order, see A3A_fnc_lootDeliveryRequest
    <OBJECT> Delivery vehicle

Return Value:
    <STRING> Marker name

Scope: Server
Environment: Any
Public: No
Dependencies:

Example:
    private _vehMarker = [_order, _veh] call A3A_fnc_lootDeliveryMarker;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

// Seconds between position updates
#define MARKER_REFRESH 10

params ["_order", "_veh"];
_order params ["_id", "_mode"];

private _marker = createMarker [format ["A3A_lootDelivery_veh_%1", _id], getPosATL _veh];
_marker setMarkerShape "ICON";
_marker setMarkerType (["c_car", "c_plane"] select (_mode == "plane"));
_marker setMarkerColor colorTeamPlayer;
_marker setMarkerText localize ("STR_A3A_fn_logistics_lootDelivery_marker_" + _mode);

[_marker, _veh] spawn {
    params ["_marker", "_veh"];
    // The marker is deleted by A3A_fnc_lootDeliveryFinish, a deleted marker has no type
    while { markerType _marker != "" && { !isNull _veh } && { alive _veh } } do {
        _marker setMarkerPos getPosATL _veh;
        sleep MARKER_REFRESH;
    };
};

_marker
