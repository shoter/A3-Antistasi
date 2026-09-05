/*
Maintainer: Shoter
    Returns the persistent statistics record of a player, creating it with default values when missing.
    Keys that are missing or hold a wrong type (records from older saves, tampered saves) are reset to their defaults.

Arguments:
    <STRING> Player UID

Return Value:
    <HASHMAP> Statistics record, the same object that is stored in A3A_playerStats

Scope: Server
Environment: Any
Public: No
Dependencies:
    <HASHMAP> A3A_playerStats

Example:
    ["76561198000000000"] call A3A_fnc_playerStats_get;

License: APL-ND

*/

#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if (!isServer) exitWith {
    Error("Miscalled server-only function");
    createHashMap
};

params [["_uid", "", [""]]];

private _stats = A3A_playerStats getOrDefault [_uid, createHashMap, true];

// Every key of a record with its default. Numbers are counters, the dates are systemTimeUTC arrays.
{
    _x params ["_key", "_default"];
    if (!(_key in _stats) || {!((_stats get _key) isEqualType _default)}) then { _stats set [_key, _default] };
} forEach [
    ["name", ""],
    ["kills", 0],
    ["deaths", 0],
    ["vehicleKills", 0],
    ["airKills", 0],
    ["civilianKills", 0],
    ["friendlyKills", 0],
    ["playerKills", 0],
    ["longestKill", 0],
    ["timeOnline", 0],
    ["sessions", 0],
    ["firstSeen", []],
    ["lastSeen", []],
    ["timesDowned", 0],
    ["revives", 0],
    ["moneyEarned", 0]
];

_stats
