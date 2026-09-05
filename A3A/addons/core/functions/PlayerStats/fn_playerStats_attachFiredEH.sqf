/*
Maintainer: Shoter
    Attaches the shot counting handler of the player statistics to a player body, once per body.
    Shots from a vehicle weapon count for the vehicle class, shots on foot for the weapon class.
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
    params ["", "_weapon", "", "", "", "", "", "_vehicle"];
    private _key = if (isNull _vehicle) then { _weapon } else { typeOf _vehicle };
    if (_key in ["", "Throw", "Put"]) exitWith {};
    A3A_playerStats_shotsBuffer set [_key, (A3A_playerStats_shotsBuffer getOrDefault [_key, 0]) + 1];
}];
