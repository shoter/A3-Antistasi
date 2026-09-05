/*
Maintainer: Shoter
    Finds the soldier responsible for a kill, the way the rest of Antistasi credits kills:
    the instigator when the engine only reports a vehicle, the unit that downed the victim when a revive system
    finished it off with setDamage, and whoever is in charge of a vehicle for roadkills.

Arguments:
    <OBJECT> Victim
    <OBJECT> Killer as reported by the Killed / EntityKilled event
    <OBJECT> Instigator as reported by the event, may be objNull        [DEFAULT=objNull]

Return Value:
    <OBJECT> Responsible soldier (isKindOf CAManBase) or objNull

Scope: Any
Environment: Any
Public: No

Example:
    private _shooter = [_victim, _killer, _instigator] call A3A_fnc_playerStats_resolveKiller;

License: APL-ND

*/

params [["_victim", objNull, [objNull]], ["_killer", objNull, [objNull]], ["_instigator", objNull, [objNull]]];

private _shooter = _killer;

// The engine reports the vehicle as the killer, the instigator is the one who pulled the trigger
if ((isNull _shooter || {!(_shooter isKindOf "CAManBase")}) && {!isNull _instigator}) then {
    _shooter = _instigator;
};

// Revive systems finish off units with setDamage, which reports the victim as its own killer.
// Both revive systems remember who actually downed the unit.
if (isNull _shooter || {_shooter == _victim}) then {
    private _downedBy = _victim getVariable ["A3A_downedBy", objNull];
    if (isNull _downedBy && {missionNamespace getVariable ["A3A_hasACE", false]}) then {
        _downedBy = _victim getVariable ["ace_medical_lastDamageSource", objNull];
    };
    if (!isNull _downedBy) then { _shooter = _downedBy };
};

if (isNull _shooter || {_shooter == _victim}) exitWith { objNull };

// Roadkills and vehicle weapons without an instigator: credit whoever is in charge of the vehicle
if !(_shooter isKindOf "CAManBase") then {
    _shooter = effectiveCommander _shooter;
};

if (isNull _shooter || {!(_shooter isKindOf "CAManBase")}) exitWith { objNull };

_shooter
