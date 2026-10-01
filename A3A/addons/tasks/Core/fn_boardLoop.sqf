/*
Maintainer: Shoter
    Mission board loop. Missions are no longer handed out on request or started at random: the board posts
    3 new missions every 15 minutes and retires 1-2 random ones, and players pick from it (Petros' mission action
    or the commander's Mission board button). The board starts with 2 missions per category, and is topped up
    to that again when the HQ moves, since missions too far from the new HQ drop off.
    The board is saved with the campaign (A3A_tasks_fnc_boardSave). A loaded campaign starts with the saved board,
    minus missions that no longer fit, topped up the same way. Missions already taken are not saved.

Arguments:
    None

Return Value:
    None, runs forever

Scope: Server
Environment: Scheduled
Public: No

Example:
    [] spawn A3A_tasks_fnc_boardLoop;
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

#define BOARD_INTERVAL 900
#define BOARD_START_PER_CATEGORY 2

if (!isServer) exitWith { Error("Server-only function miscalled") };

A3A_missionBoard = [];
A3A_missionBoardUID = 0;
if (!isNil "A3A_missionBoardSaved") then {
    [A3A_missionBoardSaved] call FUNC(boardRestore);
    A3A_missionBoardSaved = nil;
};
call FUNC(boardPublish);

["HQPlaced", "A3A_missionBoard_HQPlaced", {
    [0, 0, BOARD_START_PER_CATEGORY] spawn FUNC(boardUpdate);
}] call A3A_Events_fnc_addEventListener;

waitUntil { sleep 5; !(missionNamespace getVariable ["A3A_petrosMoving", false]) };
[0, 0, BOARD_START_PER_CATEGORY] call FUNC(boardUpdate);

while { true } do {
    // Clients show the countdown against serverTime (time in singleplayer)
    A3A_missionBoardNextUpdate = ([time, serverTime] select isMultiplayer) + BOARD_INTERVAL;
    publicVariable "A3A_missionBoardNextUpdate";
    sleep BOARD_INTERVAL;
    waitUntil { sleep 5; !(missionNamespace getVariable ["A3A_petrosMoving", false]) };
    [3, 1 + floor random 2] call FUNC(boardUpdate);
};
