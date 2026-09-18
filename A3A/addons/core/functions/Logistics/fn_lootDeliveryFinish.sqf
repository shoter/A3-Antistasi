/*
Maintainer: Shoter
    Terminal cleanup of a loot crate delivery, called exactly once per order.
    Home again: vehicle and crew despawn, deposit and HR go back to whoever paid them.
    Lost (destroyed, driver dead, stuck past the time limit): nothing is refunded, the vehicle marker and,
    when the crate never came down, the drop marker turn red and disappear after 60 seconds.
    Never spawned: everything is refunded.

Arguments:
    <ARRAY> Delivery order, see A3A_fnc_lootDeliveryRequest
    <OBJECT> Delivery vehicle (may be objNull or dead)
    <GROUP> Crew group
    <STRING> Vehicle marker
    <BOOL> True when the crate was dropped
    <BOOL> True when the vehicle made it back to HQ
    <BOOL> True when the vehicle could not be spawned at all [DEFAULT = false]

Return Value:
    <nil>

Scope: Server
Environment: Any
Public: No
Dependencies:
    A3A_fnc_resourcesFIA, A3A_fnc_resourcesPlayer, A3A_fnc_lootDeliveryHint, A3A_fnc_VEHdespawner, A3A_fnc_groupDespawner

Example:
    [_order, _veh, _group, _vehMarker, _dropped, _home] call A3A_fnc_lootDeliveryFinish;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

// Seconds a red marker stays on the map
#define MARKER_LINGER 60

params ["_order", "_veh", "_group", "_vehMarker", "_dropped", "_home", ["_noSpawn", false]];
_order params ["_id", "_mode", "_player", "_uid", "_factionPays", "_deposit", "_hr", "_dropMarker", "_fee"];
if (!isServer) exitWith { Error("Called on a client, server only") };

// The player object changes on respawn and goes null on disconnect
if (isNull _player) then {
    private _index = allPlayers findIf { getPlayerUID _x == _uid };
    if (_index != -1) then { _player = allPlayers # _index };
};

// Markers
if (!_dropped) then {
    _dropMarker setMarkerColor "ColorRed";
    _dropMarker spawn { sleep MARKER_LINGER; deleteMarker _this };
};
if (_vehMarker != "") then {
    if (_home) then { deleteMarker _vehMarker } else {
        _vehMarker setMarkerColor "ColorRed";
        _vehMarker spawn { sleep MARKER_LINGER; deleteMarker _this };
    };
};

// Vehicle and crew
if (_home) then {
    { deleteVehicle _x } forEach units _group;         // crew first, so the vehicle never fires an empty GetOut
    deleteVehicle _veh;
    if (!isNull _group) then { deleteGroup _group };
} else {
    if (!isNull _group) then { [_group] spawn A3A_fnc_groupDespawner };
    if (!isNull _veh) then {
        _veh lock 0;
        [_veh] spawn A3A_fnc_VEHdespawner;
    };
};

// Silent faction transaction, then refresh every top bar: a silent resourcesFIA does not do that itself
private _fnc_factionResources = {
    _this spawn {
        params ["_hrChange", "_moneyChange"];
        [_hrChange, _moneyChange, true] call A3A_fnc_resourcesFIA;
        [] remoteExec ["A3A_fnc_statistics", [teamPlayer, civilian]];
    };
};

// Refunds: the money goes back to the payer, to the faction when that player has left
private _money = 0;
if (_home) then { _money = _deposit };
if (_noSpawn) then { _money = _deposit + _fee };
if (_home || _noSpawn) then {
    if (_factionPays || { isNull _player }) then {
        [_hr, _money] call _fnc_factionResources;
    } else {
        [_money, _player] call A3A_fnc_resourcesPlayer;
        [_hr, 0] call _fnc_factionResources;
    };
};

if (!isNull _player) then {
    private _key = switch (true) do {
        case (_noSpawn): { "no_spawn" };
        case (_home): { "returned" };
        case (_dropped): { "lost_return" };
        default { "lost" };
    };
    ["STR_A3A_fn_logistics_lootDelivery_" + _key + "_" + _mode, [_money]] remoteExecCall ["A3A_fnc_lootDeliveryHint", _player];
};

private _hrBack = if (_home || _noSpawn) then { _hr } else { 0 };
Info_5("Loot delivery %1 finished: dropped %2, home %3, refunded $%4 and %5 HR", _id, _dropped, _home, _money, _hrBack);
