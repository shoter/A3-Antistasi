/*
Maintainer: Shoter
    Attaches the shot and hit counting handler of the player statistics to a player body, once per body.
    Shots from a vehicle weapon count for the vehicle class, shots on foot for the weapon class.
    Every projectile is watched on this machine, where it is local: its first impact on a living enemy soldier
    or an enemy vehicle counts as one hit for the accuracy of that weapon.
    Called by A3A_fnc_playerStats_clientInit for the first body and after respawns, and by newPlayerSetup
    for singleplayer respawns, where the body is swapped without a respawn event.

Arguments:
    <OBJECT> Player body

Return Value:
    Nothing

Scope: Clients
Environment: Any
Public: No

Example:
    [player] call A3A_fnc_playerStats_attachFiredEH;

License: APL-ND

*/

params [["_unit", objNull, [objNull]]];

if (isNull _unit || {!hasInterface} || {isNil "A3A_playerStats_shotsBuffer"}) exitWith {};
if (_unit getVariable ["A3A_playerStats_firedEH", false]) exitWith {};
_unit setVariable ["A3A_playerStats_firedEH", true];

_unit addEventHandler ["FiredMan", {
    params ["", "_weapon", "", "", "", "", "_projectile", "_vehicle"];
    private _key = if (isNull _vehicle) then { _weapon } else { typeOf _vehicle };
    if (_key in ["", "Throw", "Put"]) exitWith {};

    private _counts = A3A_playerStats_shotsBuffer getOrDefault [_key, [0, 0], true];
    _counts set [0, (_counts select 0) + 1];

    if (isNull _projectile) exitWith {};
    _projectile setVariable ["A3A_playerStats_key", _key];
    _projectile addEventHandler ["HitPart", {
        params ["_projectile", "_hitEntity"];
        // One hit per shot, penetrations and ricochets do not count twice
        if (_projectile getVariable ["A3A_playerStats_hit", false]) exitWith {};
        if !([_hitEntity] call A3A_fnc_playerStats_isEnemyTarget) exitWith {};
        _projectile setVariable ["A3A_playerStats_hit", true];
        private _counts = A3A_playerStats_shotsBuffer getOrDefault [_projectile getVariable ["A3A_playerStats_key", ""], [0, 0], true];
        _counts set [1, (_counts select 1) + 1];
    }];
}];
