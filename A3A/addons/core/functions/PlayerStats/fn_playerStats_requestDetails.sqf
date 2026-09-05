/*
Maintainer: Shoter
    Server-side function that sends the full statistics record of one player to the Players tab of the requesting client,
    together with the profile values (rank, score, money, missions) taken from the unit when the player is online
    and from the personal save otherwise.

Arguments:
    <NUMBER> Client owner ID to send the details to.
    <STRING> Player UID

Return Value:
    Nothing

Scope: Server, Local Arguments, Global Effect
Environment: Unscheduled
Public: No
Dependencies:
    <HASHMAP> A3A_playerStats
    <HASHMAP> A3A_playerSessions
    <HASHMAP> A3A_playerSaveData
    <ARRAY> membersX

Example:
    [clientOwner, "76561198000000000"] remoteExecCall ["A3A_fnc_playerStats_requestDetails", 2];

License: APL-ND

*/

#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if (!isServer) exitWith { Error("Miscalled server-only function") };

params [["_client", -1, [0]], ["_uid", "", [""]]];

if (_client < 0) exitWith { Error("No client to send player statistics to") };
if (_uid == "" || {!(_uid in A3A_playerStats)}) exitWith {};

// Copy, so the running session can be added without touching the saved record
private _stats = +([_uid] call A3A_fnc_playerStats_get);

private _currentSession = -1;
private _sessionStart = A3A_playerSessions get _uid;
if (!isNil "_sessionStart") then {
    _currentSession = (serverTime - _sessionStart) max 0;
    _stats set ["timeOnline", (_stats get "timeOnline") + _currentSession];
};

// Player body when online
private _unit = objNull;
{
    if (([_x] call A3A_fnc_playerStats_getUID) == _uid) exitWith { _unit = _x getVariable ["owner", _x] };
} forEach (allPlayers - entities "HeadlessClient_F");
private _online = !isNull _unit;

private _rank = "";
private _score = -1;
private _money = -1;
private _missions = -1;
if (_online) then {
    _stats set ["name", name _unit];
    _rank = _unit getVariable ["rankX", ""];            // rank _unit fails on corpses
    _score = _unit getVariable ["score", -1];
    _money = _unit getVariable ["moneyX", -1];
    _missions = _unit getVariable ["missionsCompleted", -1];
} else {
    private _save = A3A_playerSaveData get _uid;
    if (!isNil "_save" && {_save isEqualType createHashMap}) then {
        _rank = _save getOrDefault ["rankPlayer", ""];
        _score = _save getOrDefault ["scorePlayer", -1];
        _money = _save getOrDefault ["moneyX", -1];
        _missions = _save getOrDefault ["missionsCompleted", -1];
    };
};

// Never send odd types from tampered saves
if !(_rank isEqualType "") then { _rank = "" };
if !(_score isEqualType 0) then { _score = -1 };
if !(_money isEqualType 0) then { _money = -1 };
if !(_missions isEqualType 0) then { _missions = -1 };

["detailsReceived", [[_uid, _stats, _online, _uid in membersX, _currentSession, _rank, round _score, round _money, _missions]]] remoteExecCall ["A3A_GUI_fnc_playerStatsTab", _client];
