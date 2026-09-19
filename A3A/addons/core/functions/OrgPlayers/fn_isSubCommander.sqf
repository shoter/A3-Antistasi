/*
Maintainer: Shoter
    Whether a player was designated sub-commander by the commander.
    Sub-commanders are kept by UID in A3A_subCommanders (uid -> name), so the role survives respawns, reconnects and restarts.
    The commander is not a sub-commander because of being commander, use A3A_fnc_isCommandStaff to accept both.

Arguments:
    <OBJECT> Player unit

Return Value:
    <BOOL> True if the player is a sub-commander

Scope: Any
Environment: Any
Public: Yes
Dependencies:
    A3A_subCommanders

Example:
    [player] call A3A_fnc_isSubCommander;
*/
params [["_player", objNull, [objNull]]];

if (isNull _player) exitWith {false};
// Remote-controlled AI unit is not a sub-commander
if (_player getVariable ["owner", _player] != _player) exitWith {false};
(_player getVariable ["A3A_playerUID", getPlayerUID _player]) in A3A_subCommanders;
