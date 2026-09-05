/*
Maintainer: Shoter
    Adds to the numeric statistics of a player. Remote executed on the server by the machines that observe the events.
    Only keys that exist in the record and hold numbers are accepted, anything else is ignored.

Arguments:
    <STRING> Player UID
    <ARRAY<ARRAY>> Increments as [key, delta] pairs                                  [DEFAULT=[]]
    <ARRAY<ARRAY>> Maxima as [key, value] pairs, the key keeps the larger value       [DEFAULT=[]]

Return Value:
    Nothing

Scope: Server
Environment: Any
Public: No
Dependencies:
    <HASHMAP> A3A_playerStats

Example:
    [getPlayerUID player, [["kills", 1]], [["longestKill", 320]]] remoteExecCall ["A3A_fnc_playerStats_add", 2];

License: APL-ND

*/

#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if (!isServer) exitWith { Error("Miscalled server-only function") };

params [["_uid", "", [""]], ["_increments", [], [[]]], ["_maxima", [], [[]]]];

if (_uid == "") exitWith {};

private _stats = [_uid] call A3A_fnc_playerStats_get;

{
    _x params [["_key", "", [""]], ["_delta", 0, [0]]];
    if (_key == "" || {!(_key in _stats)} || {!((_stats get _key) isEqualType 0)}) then { continue };
    _stats set [_key, (_stats get _key) + _delta];
} forEach _increments;

{
    _x params [["_key", "", [""]], ["_value", 0, [0]]];
    if (_key == "" || {!(_key in _stats)} || {!((_stats get _key) isEqualType 0)}) then { continue };
    _stats set [_key, (_stats get _key) max _value];
} forEach _maxima;
