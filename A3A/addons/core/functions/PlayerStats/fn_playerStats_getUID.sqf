/*
Maintainer: Shoter
    Returns the UID of the player behind a unit for the player statistics.
    Falls back to the UID mirrored onto player bodies (A3A_playerUID) and to the body owning a remote-controlled AI,
    so the UID is still found while the player remote controls a unit or has just disconnected.

Arguments:
    <OBJECT> Unit

Return Value:
    <STRING> Player UID, "" when no player is behind the unit

Scope: Any
Environment: Any
Public: No

Example:
    [player] call A3A_fnc_playerStats_getUID;

License: APL-ND

*/

params [["_unit", objNull, [objNull]]];

if (isNull _unit) exitWith { "" };

private _uid = getPlayerUID _unit;
if (_uid != "") exitWith { _uid };

_uid = _unit getVariable ["A3A_playerUID", ""];
if (_uid != "") exitWith { _uid };

// Remote-controlled AIs point at the body of the controlling player, vehicles may carry a group here
private _owner = _unit getVariable ["owner", objNull];
if (!(_owner isEqualType objNull) || {isNull _owner} || {_owner == _unit}) exitWith { "" };

_uid = getPlayerUID _owner;
if (_uid != "") exitWith { _uid };

_owner getVariable ["A3A_playerUID", ""]
