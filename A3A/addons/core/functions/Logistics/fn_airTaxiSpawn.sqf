/*
Maintainer: Shoter
    Spawns an air taxi helicopter in the air above its origin with a single AI pilot.
    Restores the garaged state and customisation, then locks the pilot seat and the turrets
    so passengers can only take cargo seats. The pilot is not a spawner and not part of any HC squad.

Arguments:
    <STRING> Helicopter classname
    <ARRAY> Garage entry [displayName, class, lockUID, checkoutUID, state, lockName, customisation, lockTime]
    <POSITION> Spawn position (origin base)
    <POSITION> Position to face (pickup landing zone)
    <OBJECT> Requesting player, stored as owner

Return Value:
    <ARRAY> [<OBJECT> helicopter, <GROUP> crew group], [objNull, grpNull] on failure

Scope: Server
Environment: Unscheduled
Public: No
Dependencies:
    HR_GRG_fnc_prepPylons, HR_GRG_fnc_setState, A3A_fnc_safeVehicleSpawn, A3A_fnc_AIVEHinit

Example:
    [_class, _entry, _originPos, _pickupLZ, _player] call A3A_fnc_airTaxiSpawn params ["_heli", "_crewGroup"];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [
    ["_class", "", [""]],
    ["_entry", [], [[]]],
    ["_spawnPos", [0,0,0], [[]]],
    ["_facePos", [0,0,0], [[]]],
    ["_player", objNull, [objNull]]
];

private _heli = [_class, _spawnPos, 100, 5, true] call A3A_fnc_safeVehicleSpawn;       // Air: created at +100 m in "FLY"
if (isNull _heli) exitWith {
    Error_1("Air taxi could not spawn %1", _class);
    [objNull, grpNull];
};

// Restore the garaged state, as the garage placement does
[_heli] call HR_GRG_fnc_prepPylons;
[_heli, _entry param [4, []]] call HR_GRG_fnc_setState;
private _customisation = _entry param [6, []];
if (_customisation isEqualType [] && { count _customisation == 2 }) then {
    ([_heli] + _customisation) call BIS_fnc_initVehicle;
};
_heli setFuel 1;            // the fare includes fuel

// Face the pickup zone, keep the airspeed
private _velocity = velocityModelSpace _heli;
_heli setDir (_heli getDir _facePos);
_heli setVelocityModelSpace _velocity;

[_heli, teamPlayer] call A3A_fnc_AIVEHinit;
_heli setVariable ["ownerX", getPlayerUID _player, true];
_heli setVariable ["A3A_airTaxi", true, true];          // exempts it from the garbage cleaner

// Pilot only, no FIAinit (it would make the pilot a spawner)
private _crewGroup = createGroup [teamPlayer, true];
private _pilot = [_crewGroup, FactionGet(reb,"unitCrew"), getPos _heli, [], 0, "NONE"] call A3A_fnc_createUnit;
_pilot assignAsDriver _heli;
_pilot moveInDriver _heli;
_crewGroup addVehicle _heli;
_crewGroup selectLeader _pilot;
{ _pilot disableAI _x } forEach ["TARGET", "AUTOTARGET", "AUTOCOMBAT"];
_pilot allowFleeing 0;
_pilot setBehaviour "CARELESS";
_crewGroup setBehaviourStrong "CARELESS";
_pilot setVariable ["A3A_airTaxiCrew", true, true];

// Passengers may only take cargo seats
_heli lockDriver true;
{ _heli lockTurret [_x, true] } forEach allTurrets [_heli, false];
driver _heli action ["engineOn", _heli];

Info_3("Air taxi %1 spawned at %2 for %3", _class, _spawnPos, name _player);
[_heli, _crewGroup]
