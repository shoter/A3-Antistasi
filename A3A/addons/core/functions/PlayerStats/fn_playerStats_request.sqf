/*
Maintainer: Shoter
    Server-side function that sends the player statistics list to the Players tab of the requesting client.
    One row per player that ever played: [uid, name, kills, deaths, time online in seconds, online, member].
    The time online includes the running session of connected players.

Arguments:
    <NUMBER> Client owner ID to send the list to.

Return Value:
    Nothing

Scope: Server, Local Arguments, Global Effect
Environment: Unscheduled
Public: No
Dependencies:
    <HASHMAP> A3A_playerStats
    <HASHMAP> A3A_playerSessions
    <ARRAY> membersX

Example:
    [clientOwner] remoteExecCall ["A3A_fnc_playerStats_request", 2];

License: APL-ND

*/

#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if (!isServer) exitWith { Error("Miscalled server-only function") };

params [["_client", -1, [0]]];

if (_client < 0) exitWith { Error("No client to send player statistics to") };

private _now = serverTime;

// uid -> player body of everyone connected, so online players show their current name
private _onlineUnits = createHashMap;
{
    private _uid = [_x] call A3A_fnc_playerStats_getUID;
    if (_uid != "") then { _onlineUnits set [_uid, _x getVariable ["owner", _x]] };
} forEach (allPlayers - entities "HeadlessClient_F");

private _rows = [];
{
    private _uid = _x;
    private _stats = _y;
    if !(_stats isEqualType createHashMap) then { continue };

    private _timeOnline = _stats getOrDefault ["timeOnline", 0];
    private _session = A3A_playerSessions get _uid;
    if (!isNil "_session") then { _timeOnline = _timeOnline + ((_now - (_session select 0)) max 0) };

    private _online = _uid in _onlineUnits;
    private _name = if (_online) then { name (_onlineUnits get _uid) } else { _stats getOrDefault ["name", ""] };
    if (!(_name isEqualType "") || {_name == ""}) then { _name = _uid };

    _rows pushBack [_uid, _name, _stats getOrDefault ["kills", 0], _stats getOrDefault ["deaths", 0], _timeOnline, _online, _uid in membersX];
} forEach A3A_playerStats;

["dataReceived", [_rows]] remoteExecCall ["A3A_GUI_fnc_playerStatsTab", _client];
