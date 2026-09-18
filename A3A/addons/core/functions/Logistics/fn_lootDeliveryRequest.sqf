/*
Maintainer: Shoter
    Server side of the Loot crate button of the Battle Command menu. Validates the order, charges the
    payer (faction funds for the commander, personal money for everyone else, HR always from the faction),
    places the drop marker and starts the pickup or plane run.

Arguments:
    <OBJECT> Player ordering the crate
    <STRING> "pickup" or "plane"
    <POSITION> Drop position, where the player stood when they opened the order dialog
    <NUMBER> clientOwner of the player, for the replies

Return Value:
    <nil>

Scope: Server
Environment: Any
Public: No
Dependencies:
    A3A_fnc_lootDeliveryInfo, A3A_fnc_lootDeliveryPickup, A3A_fnc_lootDeliveryPlane, A3A_fnc_lootDeliveryHint

Example:
    [player, "pickup", getPosATL player, clientOwner] remoteExecCall ["A3A_fnc_lootDeliveryRequest", 2];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_player", objNull, [objNull]], ["_mode", "", [""]], ["_pos", [], [[]]], ["_client", -1, [0]]];
if (!isServer) exitWith { Error("Called on a client, server only") };
if (isNull _player || { _client < 0 } || { !(_mode in ["pickup", "plane"]) } || { count _pos < 2 }) exitWith {
    Error_1("Bad loot delivery request: %1", _this);
};
if (remoteExecutedOwner > 2 && { remoteExecutedOwner != owner _player }) exitWith {
    Error_2("Loot delivery request for %1 sent by client %2", name _player, remoteExecutedOwner);
};

private _fnc_reject = {
    params ["_key"];
    Info_2("Loot delivery request by %1 rejected: %2", name _player, _key);
    ["STR_A3A_fn_logistics_lootDelivery_blk_" + _key] remoteExecCall ["A3A_fnc_lootDeliveryHint", _client];
};

_pos = [_pos # 0, _pos # 1, 0];
if (_pos distance2D _player > 100) exitWith { ["not_alive"] call _fnc_reject };          // drop position has to be the player's own

([_player, _pos] call A3A_fnc_lootDeliveryInfo) params ["_fee", "_factionPays", "", "", "_blockers", "_pickup", "_plane"];
([_pickup, _plane] select (_mode == "plane")) params ["_class", "_deposit", "_modeBlockers", ["_airport", ""]];
_blockers = _blockers + _modeBlockers;
if (_blockers isNotEqualTo []) exitWith { [_blockers # 0] call _fnc_reject };

// Silent faction transaction, then refresh every top bar: a silent resourcesFIA does not do that itself
private _fnc_factionResources = {
    _this spawn {
        params ["_hrChange", "_moneyChange"];
        [_hrChange, _moneyChange, true] call A3A_fnc_resourcesFIA;
        [] remoteExec ["A3A_fnc_statistics", [teamPlayer, civilian]];
    };
};

// Charge
private _total = _fee + _deposit;
if (_factionPays) then {
    [-1, -_total] call _fnc_factionResources;
} else {
    if !([-_total, _player] call A3A_fnc_resourcesPlayer) exitWith { _total = -1 };
    [-1, 0] call _fnc_factionResources;
};
if (_total < 0) exitWith { ["no_money"] call _fnc_reject };

// Drop marker, visible to everyone until the crate is down or the delivery is lost
A3A_lootDeliveryCount = (missionNamespace getVariable ["A3A_lootDeliveryCount", 0]) + 1;
private _id = A3A_lootDeliveryCount;
private _dropMarker = createMarker [format ["A3A_lootDelivery_drop_%1", _id], _pos];
_dropMarker setMarkerShape "ICON";
_dropMarker setMarkerType "mil_pickup";
_dropMarker setMarkerColor "ColorYellow";
_dropMarker setMarkerText format [localize "STR_A3A_fn_logistics_lootDelivery_marker_drop", name _player];

// [id, mode, player, player UID, faction pays, deposit, HR, drop marker, fee]
private _order = [_id, _mode, _player, getPlayerUID _player, _factionPays, _deposit, 1, _dropMarker, _fee];
if (_mode == "plane") then {
    [_order, _class, _pos, _airport] spawn A3A_fnc_lootDeliveryPlane;
} else {
    [_order, _class, _pos] spawn A3A_fnc_lootDeliveryPickup;
};

["STR_A3A_fn_logistics_lootDelivery_requested_" + _mode, [_total, _deposit]] remoteExecCall ["A3A_fnc_lootDeliveryHint", _client];
Info_5("Loot delivery %1 by %2 ordered by %3 to %4 for $%5", _id, _mode, name _player, mapGridPosition _pos, _total);
