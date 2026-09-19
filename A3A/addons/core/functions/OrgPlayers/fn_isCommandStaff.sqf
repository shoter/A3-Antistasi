/*
Maintainer: Shoter
    Whether a player is the commander or one of the sub-commanders.
    Command staff may recruit high command squads and pay for junkyard vehicles and utility items from the faction funds.

Arguments:
    <OBJECT> Player unit

Return Value:
    <BOOL> True if the player is the commander or a sub-commander

Scope: Any
Environment: Any
Public: Yes
Dependencies:
    A3A_fnc_isSubCommander

Example:
    if !([player] call A3A_fnc_isCommandStaff) exitWith {};
*/
params [["_player", objNull, [objNull]]];

if (isNull _player) exitWith {false};
_player == theBoss || {[_player] call A3A_fnc_isSubCommander};
