/*
Maintainer: Shoter
    Credits a kill to the player responsible for it and forwards it to the server.
    Called where the victim is local, from the Killed event handlers of enemy and civilian units,
    because the unit that downed the victim is only known on that machine.

Arguments:
    <OBJECT> Victim
    <OBJECT> Killer as reported by the Killed event
    <OBJECT> Instigator as reported by the Killed event, may be objNull        [DEFAULT=objNull]
    <STRING> Statistic to increment, "kills" or "civilianKills"                [DEFAULT="kills"]

Return Value:
    Nothing

Scope: Any
Environment: Any
Public: No

Example:
    [_victim, _killer, _this param [2, objNull], "kills"] call A3A_fnc_playerStats_reportKill;

License: APL-ND

*/

params [["_victim", objNull, [objNull]], ["_killer", objNull, [objNull]], ["_instigator", objNull, [objNull]], ["_statKey", "kills", [""]]];

if (isNull _victim || {_victim getVariable ["isAnimal", false]}) exitWith {};

// Kills count enemy soldiers only. Surrendered units have dropped their weapons, executing them is not a kill.
if (_statKey == "kills" && {count weapons _victim < 1 || {!((side group _victim) in [Occupants, Invaders])}}) exitWith {};

private _shooter = [_victim, _killer, _instigator] call A3A_fnc_playerStats_resolveKiller;
if (isNull _shooter || {!isPlayer _shooter} || {side group _shooter != teamPlayer}) exitWith {};

private _uid = [_shooter] call A3A_fnc_playerStats_getUID;
if (_uid == "") exitWith {};

private _maxima = [];
if (_statKey == "kills") then {
    _maxima = [["longestKill", round (_shooter distance _victim)]];
};

[_uid, [[_statKey, 1]], _maxima] remoteExecCall ["A3A_fnc_playerStats_add", 2];
