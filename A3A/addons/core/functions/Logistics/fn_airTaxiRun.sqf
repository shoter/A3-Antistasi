/*
Maintainer: Shoter
    Flies an air taxi from the moment it is airborne at its origin until it is back in the garage:
    approach, landing at the pickup zone, boarding wait, flight to the destination, landing or
    hover drop, unload, return to base. Ends by calling A3A_fnc_airTaxiFinish exactly once.

    Outcomes reported to A3A_fnc_airTaxiFinish: completed, no_spawn, hostile_lz, landing_failed,
    player_lost, no_show, stuck, destroyed.

Arguments:
    <OBJECT> Requesting player
    <STRING> Requesting player UID
    <OBJECT> Helicopter
    <GROUP> Crew group
    <POSITION> Origin position to return to
    <POSITION> Pickup landing zone
    <STRING> Destination marker
    <POSITION> Destination landing zone, [] for a hover drop
    <NUMBER> Garage vehicle UID
    <ARRAY> Garage entry copied at request time
    <NUMBER> Fare paid
    <NUMBER> HR paid

Return Value:
    <nil>

Scope: Server
Environment: Scheduled, spawned
Public: No
Dependencies:
    A3A_fnc_heliLandAtPos, A3A_fnc_airTaxiFindLZ, A3A_fnc_airTaxiBoard, A3A_fnc_airTaxiUnload, A3A_fnc_airTaxiFinish

Example:
    [_player, _uid, _heli, _crewGroup, _originPos, _pickupLZ, _destMarker, _destLZ, _vehUID, _entry, _money, _hr] spawn A3A_fnc_airTaxiRun;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params ["_player", "_uid", "_heli", "_crewGroup", "_originPos", "_pickupLZ", "_destMarker", "_destLZ", "_vehUID", "_entry", "_money", "_hr"];

_crewGroup setVariable ["A3A_AIScriptHandle", _thisScript];
private _midHeight = [100, 150] select (A3A_climate isEqualTo "tropical");
private _destPos = markerPos _destMarker;
private _destName = [_destMarker] call A3A_fnc_localizar;
private _outcome = "";              // "" while the trip is still on
private _passengers = [];
private _landPad = objNull;

/////////////
// Helpers //
/////////////

private _fnc_heliOK = { !isNull _heli && { alive _heli } && { canMove _heli } && { alive driver _heli } };
private _fnc_playerOK = { !isNull _player && { alive _player } };
private _fnc_failReason = { if (isNull _heli || { !alive _heli }) then { "destroyed" } else { _this } };
private _fnc_setPhase = { if (!isNull _player) then { _player setVariable ["A3A_airTaxi", [_heli, _this], true] } };
private _fnc_hint = {
    params ["_key", ["_args", []], ["_targets", [_player]]];
    _targets = _targets select { !isNull _x && { isPlayer _x } };
    if (_targets isEqualTo []) exitWith {};
    ["STR_A3A_fn_logistics_airTaxi_" + _key, _args] remoteExecCall ["A3A_fnc_airTaxiHint", _targets];
};
private _fnc_deadline = { params ["_from", "_to"]; time + 60 + (_from distance2D _to) / 25 };
private _fnc_wait = {
    // Waits for a condition, gives up when the helicopter is out of action or the deadline passes
    params ["_condition", "_deadline"];
    waitUntil { sleep 1; (call _condition) || { !(call _fnc_heliOK) } || { time > _deadline } };
    (call _condition) && { call _fnc_heliOK }
};
private _fnc_flyTo = {
    params ["_pos"];
    { deleteWaypoint _x } forEachReversed waypoints _crewGroup;
    private _wp = _crewGroup addWaypoint [_pos, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "FULL";
    _wp setWaypointBehaviour "CARELESS";
    _wp setWaypointCompletionRadius 150;
    _crewGroup setCurrentWaypoint _wp;
    driver _heli action ["engineOn", _heli];        // needed for some helis (eg Ghost Hawk)
};
private _fnc_takeOff = {
    // Returns true once the helicopter is airborne and heading for _pos
    params ["_pos"];
    if (!isNull _landPad) then { deleteVehicle _landPad; _landPad = objNull };
    _heli setVariable ["LandingPad", nil, true];
    _heli land "NONE";
    _heli flyInHeight _midHeight;
    [_pos] call _fnc_flyTo;
    private _start = time;
    private _kicks = [15, 30];          // re-issue the order if the AI sits on the ground
    private _nudged = false;
    waitUntil {
        sleep 1;
        private _elapsed = time - _start;
        if (_kicks isNotEqualTo [] && { _elapsed >= _kicks # 0 }) then { _kicks deleteAt 0; [_pos] call _fnc_flyTo };
        if (_elapsed >= 45 && !_nudged) then { _nudged = true; _heli setVelocity [0, 0, 3] };
        ((getPosATL _heli) # 2 > 10 && { !isTouchingGround _heli }) || { !(call _fnc_heliOK) } || { _elapsed > 60 }
    };
    (getPosATL _heli) # 2 > 10 && { call _fnc_heliOK }
};
private _fnc_unload = {
    private _groundPos = getPosATL _heli;
    _groundPos set [2, 0];
    private _humans = _passengers select { !isNull _x && { isPlayer _x } };
    [_heli, _groundPos] remoteExec ["A3A_fnc_airTaxiUnload", [2] + _humans];
    private _end = time + 20;
    waitUntil {
        sleep 1;
        if (alive _heli) then { _heli setVelocity [0, 0, [0, -0.5] select isTouchingGround _heli] };
        ((crew _heli) - (units _crewGroup)) isEqualTo [] || { time > _end } || { !alive _heli }
    };
    { [_x] remoteExec ["moveOut", _x] } forEach ((crew _heli) - (units _crewGroup));      // stragglers
};

/////////////
// INBOUND //
/////////////

"INBOUND" call _fnc_setPhase;
[_pickupLZ] call _fnc_flyTo;
sleep 6;
if (isNull _heli || { !alive _heli }) then { _outcome = "no_spawn" };       // exploded on spawn, removed by cleanserVeh

if (_outcome == "") then {
    private _arrived = [{ _heli distance2D _pickupLZ < 1500 }, [getPosATL _heli, _pickupLZ] call _fnc_deadline] call _fnc_wait;
    if (!_arrived) then { _outcome = "landing_failed" call _fnc_failReason };
};

// Re-plan the pickup zone once the helicopter is close: the player may have moved or enemies arrived
if (_outcome == "") then {
    if !(call _fnc_playerOK) then { _outcome = "player_lost" } else {
        private _playerPos = getPosATL _player;
        if (_playerPos distance2D _pickupLZ > 300 || { [_pickupLZ] call A3A_fnc_enemyNearCheck }) then {
            private _newLZ = [_playerPos, true, [_pickupLZ]] call A3A_fnc_airTaxiFindLZ;
            if (_newLZ isEqualTo []) then { _outcome = "hostile_lz" } else { _pickupLZ = _newLZ };
        };
    };
};

////////////////////
// PICKUP LANDING //
////////////////////

if (_outcome == "") then {
    "LANDING" call _fnc_setPhase;
    ["landing"] call _fnc_hint;
    private _landed = false;
    for "_try" from 1 to 2 do {
        ([_heli, _crewGroup, _pickupLZ, 0, 120] call A3A_fnc_heliLandAtPos) params ["_ok", "_pad"];
        _landPad = _pad;
        if (_ok) exitWith { _landed = true };
        deleteVehicle _landPad; _landPad = objNull;
        if !(call _fnc_heliOK) exitWith {};
        private _centre = if (call _fnc_playerOK) then { getPosATL _player } else { _pickupLZ };
        private _newLZ = [_centre, true, [_pickupLZ]] call A3A_fnc_airTaxiFindLZ;
        if (_newLZ isEqualTo []) exitWith {};
        _pickupLZ = _newLZ;
    };
    if (!_landed) then { _outcome = "landing_failed" call _fnc_failReason };
};

//////////////
// BOARDING //
//////////////

if (_outcome == "") then {
    "BOARDING" call _fnc_setPhase;
    private _expected = [_player];
    if (call _fnc_playerOK && { _player == leader group _player }) then {
        _expected = (units group _player inAreaArray [getPosATL _player, 50, 50]) select { alive _x && { !(_x getVariable ["incapacitated", false]) } };
        _expected pushBackUnique _player;
    };
    _expected = _expected select { !isNull _x };
    private _humans = _expected select { isPlayer _x };
    [_heli, _expected, serverTime + A3A_airTaxiBoardTime] remoteExec ["A3A_fnc_airTaxiBoard", [2] + _humans];

    private _boardEnd = time + A3A_airTaxiBoardTime;
    private _grace = time + 5;
    while { time < _boardEnd } do {
        _heli setVelocity [0, 0, -0.5];                                   // bit of help to keep the thing stable
        if !(call _fnc_heliOK) exitWith {};
        if (time > _grace && { (_expected select { alive _x }) findIf { !(_x in _heli) } == -1 }) exitWith {};
        sleep 1;
    };
    _passengers = (crew _heli) - (units _crewGroup);
    if !(call _fnc_heliOK) then { _outcome = "stuck" call _fnc_failReason } else {
        if (_passengers isEqualTo []) then { _outcome = "no_show" };
    };
};

/////////////
// TAKEOFF //
/////////////

private _target = if (_destLZ isEqualTo []) then { _destPos } else { _destLZ };
if (_outcome == "") then {
    "ENROUTE" call _fnc_setPhase;
    ["departed", [_destName], _passengers] call _fnc_hint;
    if !([_target] call _fnc_takeOff) then { _outcome = "stuck" call _fnc_failReason };
};

/////////////
// ENROUTE //
/////////////

if (_outcome == "") then {
    private _arrived = [{ _heli distance2D _target < 1500 }, [getPosATL _heli, _target] call _fnc_deadline] call _fnc_wait;
    if (!_arrived) then { _outcome = "destroyed" };         // out of action with passengers aboard, the trip is lost either way
};

/////////////////////////
// DESTINATION LANDING //
/////////////////////////

if (_outcome == "") then {
    "LANDING" call _fnc_setPhase;
    private _landed = false;
    private _blacklist = [];
    if (_destLZ isNotEqualTo [] && { [_destLZ] call A3A_fnc_enemyNearCheck }) then {
        _blacklist pushBack _destLZ;
        _destLZ = [_destPos, true, _blacklist] call A3A_fnc_airTaxiFindLZ;
    };
    if (_destLZ isNotEqualTo []) then {
        ([_heli, _crewGroup, _destLZ, 0, 120] call A3A_fnc_heliLandAtPos) params ["_ok", "_pad"];
        _landPad = _pad;
        _landed = _ok;
        if (!_ok) then { deleteVehicle _landPad; _landPad = objNull };
    };
    if (!_landed && { call _fnc_heliOK }) then {
        // Hover drop: no usable landing zone, hold a few metres above the ground instead
        private _hoverPos = [_destPos, false, _blacklist, [[50,150],[150,300]]] call A3A_fnc_airTaxiFindLZ;
        if (_hoverPos isEqualTo []) then {
            _hoverPos = _destPos getPos [150, random 360];
            for "_i" from 1 to 20 do {
                if (!surfaceIsWater _hoverPos) exitWith {};
                _hoverPos = _destPos getPos [150, random 360];
            };
            _hoverPos set [2, 0];
        };
        ["hover_drop", [], _passengers] call _fnc_hint;
        ([_heli, _crewGroup, _hoverPos, A3A_airTaxiHoverHeight, 90] call A3A_fnc_heliLandAtPos) params ["", "_pad"];
        _landPad = _pad;
    };
    if (isNull _heli || { !alive _heli }) then { _outcome = "destroyed" };
};

////////////
// UNLOAD //
////////////

if (_outcome == "") then {
    "UNLOAD" call _fnc_setPhase;
    call _fnc_unload;
    ["arrived", [_destName], _passengers] call _fnc_hint;
    _outcome = "completed";
};

if (_outcome == "stuck" && { alive _heli }) then {
    // Could not take off with passengers aboard, let them out where they are
    call _fnc_unload;
};

if (_outcome != "completed") then { [_outcome] call _fnc_hint };

////////////////////
// RETURN TO BASE //
////////////////////

if (_outcome != "stuck" && { call _fnc_heliOK }) then {
    "RTB" call _fnc_setPhase;
    private _flying = (getPosATL _heli) # 2 > 10 && { !isTouchingGround _heli };
    if (_flying) then { [_originPos] call _fnc_flyTo } else { _flying = [_originPos] call _fnc_takeOff };
    if (_flying) then {
        [{ _heli distance2D _originPos < 300 }, [getPosATL _heli, _originPos] call _fnc_deadline] call _fnc_wait;
    };
};

[_player, _uid, _heli, _crewGroup, _vehUID, _entry, _money, _hr, _outcome] call A3A_fnc_airTaxiFinish;
