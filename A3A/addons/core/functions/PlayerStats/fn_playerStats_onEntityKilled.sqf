/*
Maintainer: Shoter
    Server side statistics hook for every kill: player deaths, lost player vehicles, destroyed enemy vehicles,
    friendly kills and kills of enemy players. Enemy infantry and civilian kills are credited where the victim
    is local, see A3A_fnc_playerStats_reportKill.

Arguments:
    <OBJECT> Victim
    <OBJECT> Killer as reported by EntityKilled
    <OBJECT> Instigator as reported by EntityKilled

Return Value:
    Nothing

Scope: Server
Environment: Any
Public: No

Example:
    [_victim, _killer, _instigator] call A3A_fnc_playerStats_onEntityKilled;

License: APL-ND

*/

#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if (!isServer) exitWith { Error("Miscalled server-only function") };

params [["_victim", objNull, [objNull]], ["_killer", objNull, [objNull]], ["_instigator", objNull, [objNull]]];

if (isNull _victim) exitWith {};

private _isMan = _victim isKindOf "CAManBase";

if (_isMan) then {
    // Deaths: only real player bodies. Player bodies have "owner" set to themselves, remote-controlled AIs to the controlling player.
    if ((_victim getVariable ["owner", objNull]) isEqualTo _victim) then {
        private _uid = [_victim] call A3A_fnc_playerStats_getUID;
        if (_uid != "") then { [_uid, [["deaths", 1]]] call A3A_fnc_playerStats_add };
    };
} else {
    // Vehicles bought by players carry their UID
    private _ownerUID = _victim getVariable ["ownerX", ""];
    if (_ownerUID isEqualType "" && {_ownerUID in A3A_playerStats}) then { [_ownerUID, [["vehiclesLost", 1]]] call A3A_fnc_playerStats_add };
};

private _shooter = [_victim, _killer, _instigator] call A3A_fnc_playerStats_resolveKiller;
if (isNull _shooter || {!isPlayer _shooter} || {side group _shooter != teamPlayer}) exitWith {};
// A player shooting their own body while remote controlling is neither a kill nor a friendly kill
if ((_shooter getVariable ["owner", _shooter]) isEqualTo _victim) exitWith {};

private _uid = [_shooter] call A3A_fnc_playerStats_getUID;
if (_uid == "") exitWith {};

private _increments = [];
private _weapons = [];
private _weapon = [_shooter] call A3A_fnc_playerStats_weaponClass;
if (_isMan) then {
    if (_victim getVariable ["isAnimal", false]) exitWith {};
    private _victimSide = side group _victim;
    if (_victimSide == teamPlayer) then {
        _increments pushBack ["friendlyKills", 1];
    } else {
        // Enemy players have no enemyUnitKilledEH, so PvP kills are credited here
        if (isPlayer _victim && {_victimSide == Occupants || _victimSide == Invaders}) then {
            _increments pushBack ["kills", 1];
            _increments pushBack ["playerKills", 1];
            if (_weapon != "") then { _weapons pushBack [_weapon, [0, 1, 0, 0, 0]] };
        };
    };
} else {
    // Antistasi-created enemy vehicles carry ownerSide; their crews are credited through their own Killed events
    private _ownerSide = _victim getVariable ["ownerSide", sideUnknown];
    if (_ownerSide == Occupants || _ownerSide == Invaders) then {
        _increments pushBack ["vehicleKills", 1];
        private _isAir = _victim isKindOf "Air";
        if (_isAir) then { _increments pushBack ["airKills", 1] };
        if (_weapon != "") then { _weapons pushBack [_weapon, [0, 0, [1, 0] select _isAir, [0, 1] select _isAir, 0]] };
    };
};

if (_increments isEqualTo []) exitWith {};
[_uid, _increments, [], _weapons] call A3A_fnc_playerStats_add;
