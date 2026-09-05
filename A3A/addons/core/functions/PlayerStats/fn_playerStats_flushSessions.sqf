/*
Maintainer: Shoter
    Moves the elapsed time of every running statistics session into the saved time online and restarts the flush
    point, so a server crash loses at most one autosave interval. The longest session is kept up to date as well.
    Sessions of players that are no longer connected are dropped.
    Called from A3A_fnc_saveLoop right before the statistics are written to the save.

Arguments:
    None

Return Value:
    Nothing

Scope: Server
Environment: Any
Public: No
Dependencies:
    <HASHMAP> A3A_playerStats
    <HASHMAP> A3A_playerSessions

Example:
    call A3A_fnc_playerStats_flushSessions;

License: APL-ND

*/

#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if (!isServer) exitWith { Error("Miscalled server-only function") };

private _now = serverTime;
private _nowUTC = systemTimeUTC;
private _onlineUIDs = allPlayers apply { [_x] call A3A_fnc_playerStats_getUID };

{
    _y params ["_lastFlush", "_sessionStart"];
    private _stats = [_x] call A3A_fnc_playerStats_get;
    _stats set ["timeOnline", (_stats get "timeOnline") + ((_now - _lastFlush) max 0)];
    _stats set ["longestSession", (_stats get "longestSession") max ((_now - _sessionStart) max 0)];
    _stats set ["lastSeen", _nowUTC];
} forEach A3A_playerSessions;

// Restart the flush point of connected players, drop the rest (disconnects the event handler missed)
{
    if (_x in _onlineUIDs) then {
        A3A_playerSessions set [_x, [_now, (A3A_playerSessions get _x) select 1]];
    } else {
        A3A_playerSessions deleteAt _x;
    };
} forEach (keys A3A_playerSessions);
