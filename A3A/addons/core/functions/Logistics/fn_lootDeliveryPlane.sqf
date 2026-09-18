/*
Maintainer: Shoter
    Loot crate delivery by plane: spawns a civilian plane with a civilian pilot in the air above a rebel
    airport, flies it over the drop position, releases a loot crate on a parachute and flies on to HQ,
    where it despawns in the air. Plane and pilot are on the civilian side, so enemies leave them alone.
    The parachute is steered towards the drop position, so the crate lands close to the map marker.
    Ends by calling A3A_fnc_lootDeliveryFinish exactly once.

Arguments:
    <ARRAY> Delivery order, see A3A_fnc_lootDeliveryRequest
    <STRING> Plane classname
    <POSITION> Drop position
    <STRING> Marker of the rebel airport the plane starts above

Return Value:
    <nil>

Scope: Server
Environment: Scheduled, spawned
Public: No
Dependencies:
    A3A_fnc_AIVEHinit, A3A_fnc_lootDeliveryMarker, A3A_fnc_lootDeliveryCrate, A3A_fnc_lootDeliveryFinish

Example:
    [_order, _class, _pos, _airport] spawn A3A_fnc_lootDeliveryPlane;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

// Flight altitude above ground
#define PLANE_ALTITUDE 250
// Release the crate this close to the drop position (2D), or when the plane starts flying away from it inside PLANE_PASS_DIST
#define PLANE_RELEASE_DIST 100
#define PLANE_PASS_DIST 600
// Counts as home this close to HQ (2D)
#define PLANE_HOME_DIST 400
// Top horizontal speed of the steered parachute in m/s
#define CHUTE_STEER_SPEED 6

params ["_order", "_class", "_dropPos", "_airport"];
_order params ["_id"];

///////////
// Spawn //
///////////

private _spawnPos = markerPos _airport;
_spawnPos set [2, PLANE_ALTITUDE];
private _hqPos = markerPos respawnTeamPlayer;

private _plane = createVehicle [_class, _spawnPos, [], 0, "FLY"];
if (isNull _plane) exitWith {
    Error_1("Loot delivery could not spawn %1", _class);
    [_order, objNull, grpNull, "", false, false, true] call A3A_fnc_lootDeliveryFinish;
};
private _dir = _spawnPos getDir _dropPos;
_plane setDir _dir;
_plane setPosATL _spawnPos;                                     // FLY spawns at 100 m, setPosATL kills the velocity
_plane setVelocity [60 * sin _dir, 60 * cos _dir, 0];
_plane flyInHeight PLANE_ALTITUDE;
[_plane, true, true, true, true] call A3A_fnc_clearVehicleCargo;
[_plane, civilian] call A3A_fnc_AIVEHinit;
_plane lock 2;

private _group = createGroup [civilian, true];
private _pilot = [_group, FactionGet(civ,"unitMan"), [0, 0, 0], [], 0, "NONE"] call A3A_fnc_createUnit;
_pilot assignAsDriver _plane;
_pilot moveInDriver _plane;
_group addVehicle _plane;
{ _pilot disableAI _x } forEach ["TARGET", "AUTOTARGET", "AUTOCOMBAT"];
_pilot allowFleeing 0;
_pilot setSkill 1;                                               // civilians fly badly otherwise
_group setBehaviourStrong "CARELESS";

private _vehMarker = [_order, _plane] call A3A_fnc_lootDeliveryMarker;
Info_3("Loot delivery %1: %2 spawned above %3", _id, _class, _airport);

/////////////
// Helpers //
/////////////

private _fnc_planeOK = { !isNull _plane && { alive _plane } && { canMove _plane } && { alive driver _plane } };
private _fnc_deadline = { params ["_to"]; time + 180 + (_plane distance2D _to) / 25 };
private _fnc_flyTo = {
    params ["_pos"];
    { deleteWaypoint _x } forEachReversed waypoints _group;
    private _wp = _group addWaypoint [_pos, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "NORMAL";
    _wp setWaypointBehaviour "CARELESS";
    _group setCurrentWaypoint _wp;
    _plane flyInHeight PLANE_ALTITUDE;
};

//////////////
// Outbound //
//////////////

private _dropped = false;
private _home = false;

// Aim past the drop position so the plane does not start turning before it is overhead
[_dropPos getPos [1500, _plane getDir _dropPos]] call _fnc_flyTo;

private _deadline = [_dropPos] call _fnc_deadline;
private _lastDist = _plane distance2D _dropPos;
private _release = false;
waitUntil {
    sleep 0.25;
    private _dist = _plane distance2D _dropPos;
    _release = _dist < PLANE_RELEASE_DIST || { _dist < PLANE_PASS_DIST && _dist > _lastDist + 1 };
    _lastDist = _dist;
    _release || { !(call _fnc_planeOK) } || { time > _deadline }
};

//////////
// Drop //
//////////

if (_release && { call _fnc_planeOK }) then {
    private _crate = createVehicle [FactionGet(reb,"surrenderCrate"), _plane modelToWorld [0, -12, -8], [], 0, "CAN_COLLIDE"];
    _crate allowDamage false;
    _crate setVelocity ((velocity _plane) vectorMultiply 0.3);
    _dropped = true;

    // The crate comes down on its own, the plane does not wait for it
    [_order, _crate, _dropPos] spawn {
        params ["_order", "_crate", "_dropPos"];
        sleep 2;
        private _chute = createVehicle ["B_Parachute_02_F", getPosATL _crate, [], 0, "CAN_COLLIDE"];
        _chute setVelocity velocity _crate;
        _crate attachTo [_chute, [0, 0, 0]];
        sleep 3;

        private _end = time + 180;
        waitUntil {
            sleep 0.5;
            if (isNull _chute || { isNull _crate }) exitWith { true };
            // Steer towards the marker, keep the sink rate
            private _offset = (_dropPos vectorDiff (getPosATL _chute));
            _offset set [2, 0];
            private _steer = if (vectorMagnitude _offset < 3) then { [0, 0, 0] } else {
                (vectorNormalized _offset) vectorMultiply (CHUTE_STEER_SPEED min ((vectorMagnitude _offset) / 3))
            };
            _chute setVelocity [_steer # 0, _steer # 1, (velocity _chute) # 2];
            (getPosATL _crate) # 2 < 2 || { (velocity _chute) # 2 > -0.1 } || { time > _end }
        };
        if (isNull _crate) exitWith { [_order, false] call A3A_fnc_lootDeliveryCrate };
        detach _crate;
        if (!isNull _chute) then { deleteVehicle _chute };
        private _landPos = getPosATL _crate;
        _landPos set [2, 0];
        _crate setPosATL _landPos;
        _crate setVelocity [0, 0, 0];
        sleep 1;
        _crate allowDamage true;
        [_order, _crate] call A3A_fnc_lootDeliveryCrate;
    };
};

////////////
// Return //
////////////

if (_dropped && { call _fnc_planeOK }) then {
    [_hqPos] call _fnc_flyTo;
    _deadline = [_hqPos] call _fnc_deadline;
    waitUntil { sleep 1; _plane distance2D _hqPos < PLANE_HOME_DIST || { !(call _fnc_planeOK) } || { time > _deadline } };
    _home = call _fnc_planeOK && { _plane distance2D _hqPos < PLANE_HOME_DIST };
};

[_order, _plane, _group, _vehMarker, _dropped, _home] call A3A_fnc_lootDeliveryFinish;
