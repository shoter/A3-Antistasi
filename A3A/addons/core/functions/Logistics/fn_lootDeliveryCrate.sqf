/*
Maintainer: Shoter
    Puts the delivered loot crate on the ground and closes the drop marker: green at the crate for
    60 seconds on success, red for 60 seconds when the crate was lost on the way down.
    The crate is a regular loot crate: loot to crate, carry, logistics loading, garage.

Arguments:
    <ARRAY> Delivery order, see A3A_fnc_lootDeliveryRequest
    <POSITION | OBJECT | BOOL> Position to create the crate at, a crate that is already on the ground, or false when it was lost

Return Value:
    <OBJECT> The crate, objNull when lost

Scope: Server
Environment: Any
Public: No
Dependencies:
    A3A_fnc_initObject, A3A_fnc_lootDeliveryHint

Example:
    [_order, _cratePos] call A3A_fnc_lootDeliveryCrate;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

// Seconds the finished drop marker stays on the map
#define MARKER_LINGER 60

params ["_order", "_source"];
_order params ["_id", "", "_player", "", "", "", "", "_dropMarker"];

private _crate = objNull;
if (_source isEqualType []) then {
    _crate = createVehicle [FactionGet(reb,"surrenderCrate"), _source, [], 0, "NONE"];
};
if (_source isEqualType objNull) then { _crate = _source };

if (isNull _crate) then {
    _dropMarker setMarkerColor "ColorRed";
    Info_1("Loot delivery %1: crate lost", _id);
} else {
    _crate call A3A_fnc_initObject;
    _dropMarker setMarkerPos getPosATL _crate;
    _dropMarker setMarkerColor "ColorGreen";
    if (!isNull _player) then { ["STR_A3A_fn_logistics_lootDelivery_dropped"] remoteExecCall ["A3A_fnc_lootDeliveryHint", _player] };
    Info_2("Loot delivery %1: crate dropped at %2", _id, mapGridPosition _crate);
};

_dropMarker spawn { sleep MARKER_LINGER; deleteMarker _this };
_crate
