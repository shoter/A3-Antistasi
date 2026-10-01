/*
Maintainer: Shoter
    Spawns a garaged vehicle at the origin site of a delivery with a single AI driver.
    At the HQ it takes a road slot like bought High Command vehicles, at an outpost or airport
    the nearest free spot on a road next to the site.
    Restores the garaged state and customisation, then locks the driver seat and the turrets.
    The driver is a spawner, so enemy sites along the road wake up and can intercept the delivery.

Arguments:
    <STRING> Vehicle classname
    <ARRAY> Garage entry [displayName, class, lockUID, checkoutUID, state, lockName, customisation, lockTime]
    <STRING> Origin site marker ("Synd_HQ" for the HQ)
    <POSITION> Destination position, the vehicle faces it when no road slot gives a direction
    <OBJECT> Requesting player, stored as owner

Return Value:
    <ARRAY> [<OBJECT> vehicle, <GROUP> crew group], [objNull, grpNull] on failure

Scope: Server
Environment: Any
Public: No
Dependencies:
    HR_GRG_fnc_prepPylons, HR_GRG_fnc_setState, A3A_fnc_findHQVehicleSlot, A3A_fnc_AIVEHinit

Example:
    [_class, _entry, "outpost_3", _destPos, _player] call A3A_fnc_deliverVehicleSpawn params ["_veh", "_crewGroup"];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

// Radius around the site searched for a road to start on
#define DELIVERY_ROAD_SEARCH 250

params [
    ["_class", "", [""]],
    ["_entry", [], [[]]],
    ["_origin", "", [""]],
    ["_destPos", [0,0,0], [[]]],
    ["_player", objNull, [objNull]]
];

private _veh = createVehicle [_class, [0, 0, -1000], [], 0, "CAN_COLLIDE"];
if (isNull _veh) exitWith {
    Error_1("Vehicle delivery could not spawn %1", _class);
    [objNull, grpNull];
};
_veh enableSimulation false;

// Placement
private _spawnPos = [];
private _spawnDir = [];
if (_origin == "Synd_HQ") then {
    ([_veh] call A3A_fnc_findHQVehicleSlot) params [["_slotPos", []], ["_slotDir", []]];
    _spawnPos = _slotPos;
    _spawnDir = _slotDir;
};
private _sitePos = markerPos ([_origin, respawnTeamPlayer] select (_origin == "Synd_HQ"));
if (_spawnPos isEqualTo []) then {
    // Nearest roads first, a free spot on or right next to one
    private _roads = (_sitePos nearRoads DELIVERY_ROAD_SEARCH) apply { [_x distance2D _sitePos, _x] };
    _roads sort true;
    {
        private _pos = (getPosATL (_x # 1)) findEmptyPosition [0, 12, _class];
        if (_pos isNotEqualTo [] && { !surfaceIsWater _pos }) exitWith { _spawnPos = _pos };
    } forEach (_roads select [0, 15]);
    if (_spawnPos isEqualTo []) then { _spawnPos = _sitePos findEmptyPosition [10, 120, _class] };
    if (_spawnPos isEqualTo []) then { _spawnPos = _sitePos getPos [30, random 360] };
};
if (_spawnDir isEqualTo []) then {
    isNil {
        _veh setVehiclePosition [_spawnPos, [], 0, "NONE"];
        _veh setDir (_veh getDir _destPos);
    };
} else {
    isNil {
        _veh setVehiclePosition [_spawnPos, [], 0, "CAN_COLLIDE"];
        _veh setVectorDir _spawnDir;
    };
};
_veh enableSimulation true;

// Restore the garaged state, as the garage placement does
[_veh] call HR_GRG_fnc_prepPylons;
[_veh, _entry param [4, []]] call HR_GRG_fnc_setState;
private _customisation = _entry param [6, []];
if (_customisation isEqualType [] && { count _customisation == 2 }) then {
    ([_veh] + _customisation) call BIS_fnc_initVehicle;
};

[_veh, teamPlayer] call A3A_fnc_AIVEHinit;
_veh setVariable ["ownerX", getPlayerUID _player, true];
_veh setVariable ["A3A_deliverVehicle", true, true];          // exempts it from the garbage cleaner while it is on the road

// Driver only, no FIAinit (the vehicle should not become a High Command squad)
private _crewGroup = createGroup [teamPlayer, true];
private _driver = [_crewGroup, FactionGet(reb,"unitCrew"), getPos _veh, [], 0, "NONE"] call A3A_fnc_createUnit;
_driver assignAsDriver _veh;
_driver moveInDriver _veh;
_crewGroup addVehicle _veh;
_crewGroup selectLeader _driver;
{ _driver disableAI _x } forEach ["TARGET", "AUTOTARGET", "AUTOCOMBAT"];
_driver allowFleeing 0;
_driver setBehaviour "CARELESS";
_crewGroup setBehaviourStrong "CARELESS";
_driver setVariable ["spawner", true, true];            // sites along the road spawn around the vehicle, so it can be intercepted
_driver setVariable ["A3A_deliverVehicleCrew", true, true];

// Nobody else drives or mans the guns on the way
_veh lockDriver true;
{ _veh lockTurret [_x, true] } forEach allTurrets [_veh, false];
_driver action ["engineOn", _veh];

Info_3("Vehicle delivery %1 spawned at %2 (%3)", _class, _origin, _spawnPos);
[_veh, _crewGroup]
