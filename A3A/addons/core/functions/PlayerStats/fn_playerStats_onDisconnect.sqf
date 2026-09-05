/*
Maintainer: Shoter
    Ends the statistics session of a player and adds its length to the time online.
    Called from the PlayerDisconnected mission event handler; UIDs without a session (headless clients) are ignored.

Arguments:
    <STRING> Player UID

Return Value:
    Nothing

Scope: Server
Environment: Any
Public: No
Dependencies:
    <HASHMAP> A3A_playerStats
    <HASHMAP> A3A_playerSessions

Example:
    [_this select 1] call A3A_fnc_playerStats_onDisconnect;

License: APL-ND

*/

#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if (!isServer) exitWith { Error("Miscalled server-only function") };

params [["_uid", "", [""]]];

if (_uid == "" || {!(_uid in A3A_playerSessions)}) exitWith {};

private _start = A3A_playerSessions deleteAt _uid;
private _elapsed = (serverTime - _start) max 0;

private _stats = [_uid] call A3A_fnc_playerStats_get;
_stats set ["timeOnline", (_stats get "timeOnline") + _elapsed];
_stats set ["lastSeen", systemTimeUTC];

Info_2("Ended statistics session of player %1 after %2 seconds", _uid, round _elapsed);
