/*
Maintainer: Shoter
    Starts the statistics session of a player: records the name, counts the session and remembers when it started
    so the time online can be accumulated. Idempotent, a running session is left alone.
    Called from A3A_fnc_loadPlayer and A3A_fnc_resetPlayer, which every player reaches once when entering the game.
    Headless clients never get there, so they never get a session or a record.

    A session is stored as [serverTime of the last flush, serverTime the session started].

Arguments:
    <STRING> Player UID
    <OBJECT> Player unit

Return Value:
    Nothing

Scope: Server
Environment: Any
Public: No
Dependencies:
    <HASHMAP> A3A_playerStats
    <HASHMAP> A3A_playerSessions

Example:
    [_playerId, _unit] call A3A_fnc_playerStats_onConnect;

License: APL-ND

*/

#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if (!isServer) exitWith { Error("Miscalled server-only function") };

params [["_uid", "", [""]], ["_unit", objNull, [objNull]]];

if (_uid == "" || {isNull _unit}) exitWith {};
if (_uid in A3A_playerSessions) exitWith {};

private _stats = [_uid] call A3A_fnc_playerStats_get;
private _now = systemTimeUTC;

_stats set ["name", name _unit];
_stats set ["sessions", (_stats get "sessions") + 1];
if ((_stats get "firstSeen") isEqualTo []) then { _stats set ["firstSeen", _now] };
_stats set ["lastSeen", _now];

A3A_playerSessions set [_uid, [serverTime, serverTime]];

Info_2("Started statistics session of player %1 (%2)", _uid, name _unit);
