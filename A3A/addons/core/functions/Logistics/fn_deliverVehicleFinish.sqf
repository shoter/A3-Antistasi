/*
Maintainer: Shoter
    Ends the driving part of a vehicle delivery, called exactly once per started delivery.
    Hands the vehicle over to the players wherever it stopped: unlocks it, ends the map marker and
    lets the garrison code pick it up as if it had been placed from the garage. The garage entry is
    not restored, the vehicle now lives in the world. Frees the player for another delivery.

    Outcomes:
        delivered       vehicle parked at the destination
        stranded        vehicle stuck on the way, left where it stopped
        driver_killed   driver dead or down, vehicle left where it stopped
        destroyed       vehicle destroyed on the way

Arguments:
    <OBJECT> Requesting player (may be objNull or a dead body after a respawn)
    <STRING> Requesting player UID
    <OBJECT> Vehicle (may be objNull or dead)
    <GROUP> Crew group
    <ARRAY> Garage entry copied at request time
    <POSITION> Destination position
    <STRING> Outcome

Return Value:
    <nil>

Scope: Server
Environment: Scheduled
Public: No
Dependencies:
    A3A_deliverVehicleActive, A3A_fnc_rebelVehPlacedWorker

Example:
    [_player, _uid, _veh, _crewGroup, _entry, _destPos, "delivered"] call A3A_fnc_deliverVehicleFinish;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [
    ["_player", objNull, [objNull]],
    ["_uid", "", [""]],
    ["_veh", objNull, [objNull]],
    ["_crewGroup", grpNull, [grpNull]],
    ["_entry", [], [[]]],
    ["_destPos", [0,0,0], [[]]],
    ["_outcome", "delivered", [""]]
];
if (!isServer) exitWith { Error("Called on a client, server only") };

// Bookkeeping: the player may order the next delivery while the driver walks home
A3A_deliverVehicleActive deleteAt _uid;
if (!isNull _player) then { _player setVariable ["A3A_deliverVehicle", nil, true] };
private _index = allPlayers findIf { getPlayerUID _x == _uid };
private _target = if (_index == -1) then { objNull } else { allPlayers # _index };
if (!isNull _target && { _target != _player }) then { _target setVariable ["A3A_deliverVehicle", nil, true] };

// Hand the vehicle over
private _dispName = _entry param [0, ""];
private _grid = mapGridPosition _destPos;
if (!isNull _veh) then {
    _grid = mapGridPosition _veh;
    _veh setVariable ["revealed", false, true];             // ends the A3A_fnc_vehicleMarkers loop
    if (alive _veh) then {
        _veh setVariable ["A3A_deliverVehicle", nil, true];
        _veh lockDriver false;
        { _veh lockTurret [_x, false] } forEach allTurrets [_veh, false];
        _crewGroup leaveVehicle _veh;
        [_veh] spawn A3A_fnc_rebelVehPlacedWorker;          // joins the HQ garrison when parked there, as a garage placement would
    };
};

// Status for the player
if (!isNull _target) then {
    ["STR_A3A_fn_logistics_deliverVehicle_" + _outcome, [_dispName, _grid]] remoteExecCall ["A3A_fnc_deliverVehicleHint", _target];
};

Info_4("Vehicle delivery of %1 for %2 finished: %3 at %4", _dispName, _uid, _outcome, _grid);
