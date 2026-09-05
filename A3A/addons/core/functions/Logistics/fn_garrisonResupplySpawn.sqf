/*
Maintainer: Shoter
    Spawns a garrison resupply ammo truck on a road slot at HQ with a single AI driver.
    Restores the garaged state (including the ammo points) and customisation, locks the driver seat
    and the turrets so players can only ride along in the cargo seats.
    The driver is a spawner, so enemy sites along the road and the destination spawn around the truck
    like they would around a High Command squad.

Arguments:
    <STRING> Truck classname
    <ARRAY> Garage entry [displayName, class, lockUID, checkoutUID, state, lockName, customisation, lockTime]
    <STRING> Marker of the garrison the truck is going to, stored on the truck

Return Value:
    <ARRAY> [<OBJECT> truck, <GROUP> crew group], [objNull, grpNull] on failure

Scope: Server
Environment: Scheduled (the road slot search is slow)
Public: No
Dependencies:
    A3A_fnc_findHQVehicleSlot, HR_GRG_fnc_prepPylons, HR_GRG_fnc_setState, A3A_fnc_getResourceCargo, A3A_fnc_AIVEHinit

Example:
    [_class, _entry, _marker] call A3A_fnc_garrisonResupplySpawn params ["_truck", "_crewGroup"];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_class", "", [""]], ["_entry", [], [[]]], ["_marker", "", [""]]];

private _truck = createVehicle [_class, [0, 0, -1000], [], 0, "CAN_COLLIDE"];
if (isNull _truck) exitWith {
    Error_1("Garrison resupply could not spawn %1", _class);
    [objNull, grpNull];
};
_truck enableSimulation false;

// Road slot facing out of HQ, same placement as bought High Command vehicles
([_truck] call A3A_fnc_findHQVehicleSlot) params [["_spawnPos", []], ["_spawnDir", []]];
if (_spawnPos isEqualTo []) then {
    private _searchCenter = markerPos respawnTeamPlayer getPos [50 + random 50, random 360];
    _spawnPos = _searchCenter findEmptyPosition [0, 50, _class];
    if (_spawnPos isEqualTo []) then { _spawnPos = _searchCenter };
    _truck setVehiclePosition [_spawnPos, [], 0, "NONE"];
    _truck setDir random 360;
} else {
    isNil {
        _truck setVehiclePosition [_spawnPos, [], 0, "CAN_COLLIDE"];
        _truck setVectorDir _spawnDir;
    };
};
_truck enableSimulation true;

// Restore the garaged state, as the garage placement does. The ammo points live in the ammo cargo part.
[_truck] call HR_GRG_fnc_prepPylons;
[_truck, _entry param [4, []]] call HR_GRG_fnc_setState;
if (_truck getVariable ["A3A_rearmCargo", -1] < 0) then { [_truck, "rearm"] call A3A_fnc_getResourceCargo };
private _customisation = _entry param [6, []];
if (_customisation isEqualType [] && { count _customisation == 2 }) then {
    ([_truck] + _customisation) call BIS_fnc_initVehicle;
};
_truck setFuel 1;           // the run includes fuel

[_truck, teamPlayer] call A3A_fnc_AIVEHinit;
_truck setVariable ["A3A_garrisonResupply", _marker, true];         // exempts it from the garbage cleaner

// Driver only, no FIAinit (the truck should not become a High Command squad)
private _crewGroup = createGroup [teamPlayer, true];
private _driver = [_crewGroup, FactionGet(reb,"unitCrew"), getPos _truck, [], 0, "NONE"] call A3A_fnc_createUnit;
_driver assignAsDriver _truck;
_driver moveInDriver _truck;
_crewGroup addVehicle _truck;
_crewGroup selectLeader _driver;
{ _driver disableAI _x } forEach ["TARGET", "AUTOTARGET", "AUTOCOMBAT"];
_driver allowFleeing 0;
_driver setBehaviour "CARELESS";
_crewGroup setBehaviourStrong "CARELESS";
_driver setVariable ["spawner", true, true];            // sites along the road spawn around the truck, so it can be intercepted
_driver setVariable ["A3A_garrisonResupplyCrew", true, true];

// Passengers may only take cargo seats
_truck lockDriver true;
{ _truck lockTurret [_x, true] } forEach allTurrets [_truck, false];
_driver action ["engineOn", _truck];

Info_3("Garrison resupply truck %1 spawned at %2 for %3", _class, _spawnPos, _marker);
[_truck, _crewGroup]
