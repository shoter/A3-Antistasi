/*
Maintainer: Shoter
    Starts a mission picked from the mission board and takes it off the board.
    Members or the commander only. Any number of missions of the same category can run, but at most
    BOARD_MAX_ACTIVE missions taken from the board at once. Missions that share global state run one at a time.
    Started missions are kept in A3A_missionBoardActive as [key, task, script handle] until their script ends.

Arguments:
    <NUMBER> Board entry id, from A3A_missionBoardView
    <OBJECT> Player who picked the mission
    <NUMBER> Client owner id of that player, for Petros' replies

Return Value:
    <nil>

Scope: Server
Environment: Scheduled
Public: No

Example:
    [_id, player, clientOwner] remoteExec ["A3A_tasks_fnc_boardAccept", 2];
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

#define BOARD_MAX_ACTIVE 10
// traitorIntel and the gun shop's A3A_shoppingList are global, so two of these would get in each other's way
#define BOARD_SINGLE_TASKS ["AS_Traitor", "LOG_Gunshop"]

if (!isServer) exitWith { Error("Server-only function miscalled") };

params ["_id", "_player", "_requester"];

if (A3A_petrosMoving) exitWith {};

private _fnc_reply = {
    [petros, "globalChat", localize _this] remoteExec ["A3A_fnc_commsMP", _requester];
};

if !([_player] call A3A_fnc_isMember or { _player == theBoss }) exitWith {
    "STR_antistasi_dialogs_mission_request_noCommander" call _fnc_reply;
};

// Check and take the lock unscheduled, so two scripts can't both take it
private _locked = false;
waitUntil {
    isNil { if (isNil "A3A_taskRequestInProgress") then { A3A_taskRequestInProgress = true; _locked = true } };
    _locked;
};

private _index = A3A_missionBoard findIf { (_x get "id") == _id };
if (_index == -1) exitWith {
    "STR_A3A_Tasks_board_gone" call _fnc_reply;
    A3A_taskRequestInProgress = nil;
};
private _entry = A3A_missionBoard # _index;

A3A_missionBoardActive = A3A_missionBoardActive select { !scriptDone (_x # 2) };
if (count A3A_missionBoardActive >= BOARD_MAX_ACTIVE) exitWith {
    [petros, "globalChat", format [localize "STR_A3A_Tasks_board_full", BOARD_MAX_ACTIVE]] remoteExec ["A3A_fnc_commsMP", _requester];
    A3A_taskRequestInProgress = nil;
};
if ((_entry get "task") in BOARD_SINGLE_TASKS and { A3A_missionBoardActive findIf { _x # 1 == _entry get "task" } != -1 }) exitWith {
    "STR_A3A_Tasks_board_running" call _fnc_reply;
    A3A_taskRequestInProgress = nil;
};

private _problem = [_entry, true] call FUNC(boardValidate);
if (_problem == "gone") exitWith {
    A3A_missionBoard deleteAt _index;
    call FUNC(boardPublish);
    "STR_A3A_Tasks_board_gone" call _fnc_reply;
    A3A_taskRequestInProgress = nil;
};
if (_problem == "busy") exitWith {
    "STR_A3A_Tasks_board_busy" call _fnc_reply;
    A3A_taskRequestInProgress = nil;
};

A3A_missionBoard deleteAt _index;
call FUNC(boardPublish);

private _taskFnc = missionNamespace getVariable (_entry get "func");
private _args = _entry get "args";
private _handle = if (_entry get "legacy") then {
    Trace_2("Running legacy mission %1 with params %2", _entry get "task", _args);
    _args spawn _taskFnc;
} else {
    Trace_2("Running FSM mission %1 with params %2", _entry get "task", _args);
    [_taskFnc, _args] spawn FUNC(runTask);
};
A3A_missionBoardActive pushBack [_entry get "key", _entry get "task", _handle];
ServerInfo_3("Mission board: %1 started %2 at %3", name _player, _entry get "task", _entry get "marker");

"STR_A3A_Tasks_requestTask_addMission" call _fnc_reply;
sleep 3;            // delay lockout until the mission is registered
A3A_taskRequestInProgress = nil;
