/*
Maintainer: Shoter
    Hands the forces of a won attack over to the rebel site it retook.

    Ground vehicles drive to the site and join its garrison with their crews. They respawn later
    with full health, ammo and fuel and a full crew taken from the garrison troops.
    Infantry on foot, and infantry riding in ground vehicles, gets out and walks to the site.
    It joins the garrison on arrival, or as soon as no rebels are near it.
    Joined troops don't count against the garrison size.
    Aircraft and boats return to base as before. Aircraft that make it home refund 150% of their spawn cost.

Scope: Server
Environment: Scheduled, should be spawned

Arguments:
    <STRING> Marker of the retaken site
    <SIDE> Side of the attack
    <ARRAY> Vehicles of the attack
    <ARRAY> Crew groups of the attack
    <ARRAY> Cargo groups of the attack
*/

#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params ["_marker", "_side", "_vehicles", "_crewGroups", "_cargoGroups"];

private _targPos = markerPos _marker;
ServerInfo_1("Attack forces joining the garrison of %1", _marker);


// Aircraft refund 150% of their spawn cost if they get home, damage ignored
// Covers the attack's own helicopters and the air supports (CAS, UAV, fighters) working the target area
private _aircraft = _vehicles select { alive _x and {_x isKindOf "Air"} };
{
    private _suppData = _x getVariable "SupportData";
    if (isNil "_suppData" or {!alive _x}) then { continue };
    if (_suppData#1 != _side or {_suppData#3 distance2d _targPos > 1000}) then { continue };
    _aircraft pushBackUnique _x;
} forEach (vehicles select { _x isKindOf "Air" });
{
    if (_x getVariable ["ownerSide", teamPlayer] != _side) then { continue };          // captured by rebels
    private _spawnCost = _x getVariable ["A3A_spawnCost", A3A_vehicleResourceCosts getOrDefault [typeOf _x, 0]];
    _x setVariable ["A3A_fixedRefund", 1.5 * _spawnCost, true];
    ServerDebug_2("Aircraft %1 refunds %2 if it gets home", typeOf _x, 1.5 * _spawnCost);
} forEach _aircraft;


// Foot infantry: walk to the site, join the garrison on arrival or once no rebels are near
private _fnc_groupJoin = {
    params ["_marker", "_side", "_group"];
    private _targPos = markerPos _marker;

    private _AIScriptHandle = _group getVariable "A3A_AIScriptHandle";
    if (!isNil "_AIScriptHandle") then { terminate _AIScriptHandle; _group setVariable ["A3A_AIScriptHandle", nil] };

    // Passengers of ground vehicles get out and walk
    {
        if (vehicle _x == _x) then { continue };
        _group leaveVehicle (vehicle _x);
        unassignVehicle _x;
        [_x] orderGetIn false;
    } forEach units _group;

    { deleteWaypoint _x } forEachReversed (waypoints _group);
    private _wp = _group addWaypoint [_targPos, 50];
    _group setCurrentWaypoint _wp;

    while {true} do {
        if (units _group findIf { alive _x } == -1) exitWith {};
        if (sidesX getVariable _marker != _side) exitWith {
            ServerDebug_2("Group %1 cannot join %2, site changed side", _group, _marker);
            [_group] spawn A3A_fnc_enemyReturnToBase;
        };
        // Joining a despawned site deletes the troops, so that waits until no rebels are near
        private _leader = leader _group;
        private _arrived = _leader inArea _marker or {_leader distance2d _targPos < 150};
        private _spawned = spawner getVariable _marker != 2;
        if ((_arrived and _spawned) or {!([distanceSPWN, 1, _leader, teamPlayer] call A3A_fnc_distanceUnits)}) exitWith {
            ServerDebug_2("Group %1 joining the garrison of %2", _group, _marker);
            [_group, _marker, true] call A3A_fnc_enemyGarrison;
        };
        sleep 10;
    };
};

// Ground vehicle: drive to a parking spot at the site with its crew and join the garrison
// While the site is spawned it joins once parked. Once the site has despawned it joins as soon as no rebels are near,
// and is moved to its parking spot first if it never got there.
private _fnc_vehicleJoin = {
    params ["_marker", "_side", "_vehicle", "_vehCrewGroups", "_fnc_groupJoin"];
    private _targPos = markerPos _marker;

    // Park on a free spot away from the flag
    private _parkPos = _targPos findEmptyPosition [20, 150, typeOf _vehicle];
    if (_parkPos isEqualTo []) then { _parkPos = _targPos };
    {
        private _group = _x;
        private _AIScriptHandle = _group getVariable "A3A_AIScriptHandle";
        if (!isNil "_AIScriptHandle") then { terminate _AIScriptHandle; _group setVariable ["A3A_AIScriptHandle", nil] };
        { deleteWaypoint _x } forEachReversed (waypoints _group);
        private _wp = _group addWaypoint [_parkPos, 0];
        _group setCurrentWaypoint _wp;
    } forEach _vehCrewGroups;

    while {true} do {
        // Destroyed or captured: surviving crew carries on as foot infantry
        if (!alive _vehicle or {_vehicle getVariable ["ownerSide", teamPlayer] != _side}) exitWith {
            { [_marker, _side, _x] spawn _fnc_groupJoin } forEach _vehCrewGroups;
        };
        if (sidesX getVariable _marker != _side) exitWith {
            ServerDebug_2("Vehicle %1 cannot join %2, site changed side", typeOf _vehicle, _marker);
            [_vehicle] spawn A3A_fnc_VEHDespawner;
            { [_x] spawn A3A_fnc_enemyReturnToBase } forEach _vehCrewGroups;
        };

        // Arrived means parked, or stuck inside the site. Its position becomes its garrison spot
        private _spawned = spawner getVariable _marker != 2;
        private _arrived = (_vehicle distance2d _parkPos < 25 and abs speed _vehicle < 3)
            or {(_vehicle inArea _marker or {_vehicle distance2d _targPos < 150}) and {!canMove _vehicle or {!alive driver _vehicle}}};
        private _canJoin = if (_spawned) then { _arrived } else { !([distanceSPWN, 1, _vehicle, teamPlayer] call A3A_fnc_distanceUnits) };
        if (_canJoin) exitWith {
            if (!_spawned and !_arrived) then {
                // Nobody can see it, move it to its parking spot
                _vehicle setVehiclePosition [_parkPos, [], 0, "NONE"];
            };
            ServerDebug_2("Vehicle %1 joining the garrison of %2", typeOf _vehicle, _marker);
            isNil {
                // Crew joins as garrison troops. Crew still in the vehicle stays in it
                {
                    if (units _x findIf { alive _x } == -1) then { continue };
                    [_x, _marker, true, vehicle leader _x == _vehicle] call A3A_fnc_enemyGarrison;
                } forEach _vehCrewGroups;
                [_marker, _vehicle] call A3A_fnc_garrisonServer_addJoinedVehicle;
            };
        };
        sleep 10;
    };
};


// Ground vehicles of the attack join, anything else goes home as before
private _groundVehicles = _vehicles select {
    alive _x and {_x isKindOf "LandVehicle"} and {!(_x isKindOf "StaticWeapon")} and {_x getVariable ["ownerSide", teamPlayer] == _side}
};
{ [_x] spawn A3A_fnc_VEHDespawner } forEach (_vehicles - _groundVehicles);

// Sort groups: crews stay with their ground vehicle, air and boat groups go home, everyone else walks
private _vehicleCrews = _groundVehicles apply { [] };
private _footGroups = [];
{
    private _group = _x;
    if (units _group findIf { alive _x } == -1) then { continue };
    private _veh = vehicle leader _group;
    if (_veh isKindOf "Air" or {_veh isKindOf "Ship"}) then { [_group] spawn A3A_fnc_enemyReturnToBase; continue };
    private _vehIndex = _groundVehicles find _veh;
    if (_vehIndex != -1 and {_group in _crewGroups}) then { (_vehicleCrews#_vehIndex) pushBackUnique _group; continue };
    _footGroups pushBackUnique _group;
} forEach (_crewGroups + _cargoGroups);

{ [_marker, _side, _x, _vehicleCrews#_forEachIndex, _fnc_groupJoin] spawn _fnc_vehicleJoin } forEach _groundVehicles;
{ [_marker, _side, _x] spawn _fnc_groupJoin } forEach _footGroups;
