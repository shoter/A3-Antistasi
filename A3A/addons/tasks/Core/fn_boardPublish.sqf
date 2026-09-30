/*
Maintainer: Shoter
    Sends the mission board to all clients as A3A_missionBoardView. Mission arguments stay on the server.
    Each row: [id, name stringtable key, category, location marker, reward (see A3A_tasks_fnc_boardReward), hard, convoy start marker or ""]

Arguments:
    None

Return Value:
    <nil>

Scope: Server
Environment: Any
Public: No

Example:
    call A3A_tasks_fnc_boardPublish;
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

A3A_missionBoardView = A3A_missionBoard apply {
    [_x get "id", _x get "name", _x get "category", _x get "marker", _x get "reward", _x get "hard", _x get "origin"]
};
publicVariable "A3A_missionBoardView";
