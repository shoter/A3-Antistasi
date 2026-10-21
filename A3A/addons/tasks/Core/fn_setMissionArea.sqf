/*
Maintainer: Shoter
    Sets the mission area from the Commander tab, or clears it back to the HQ and the lobby mission distance.
    Only the commander may do this. The area is broadcast as A3A_missionArea, drawn on everyone's map and saved.
    Board missions outside the new area (with the usual 1 km of slack, see A3A_tasks_fnc_boardValidate) leave
    the board, and the board is topped up with missions inside it. Missions already under way are not touched.
    While an area is set, city tasks only start in towns inside it.

Arguments:
    <OBJECT> Player requesting the change, has to be the commander
    <ARRAY> Centre position, or [] to go back to the HQ
    <NUMBER> Radius in metres: 3000, 5000, 7000, 9000 or 11000. Ignored when clearing [DEFAULT = 0]

Return Value:
    <BOOL> True if the area changed

Scope: Server
Environment: Any
Public: No
Dependencies:
    A3A_missionArea, A3A_tasks_fnc_missionAreaMarker, A3A_tasks_fnc_boardUpdate

Example:
    [player, _pos, 7000] remoteExecCall ["A3A_tasks_fnc_setMissionArea", 2];
    [player, []] remoteExecCall ["A3A_tasks_fnc_setMissionArea", 2];       // back to the HQ
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

#define AREA_RADII [3000, 5000, 7000, 9000, 11000]
#define BOARD_START_PER_CATEGORY 2

if (!isServer) exitWith { Error("Server-only function miscalled"); false };
params [["_commander", objNull, [objNull]], ["_pos", [], [[]]], ["_radius", 0, [0]]];

if (isNull _commander) exitWith { false };
if (_commander != theBoss) exitWith {
    Info_1("%1 tried to set the mission area without being commander", name _commander);
    false
};

private _newArea = [];
if (_pos isNotEqualTo []) then {
    _pos params [["_posX", -1, [0]], ["_posY", -1, [0]]];
    if (_posX < 0 or {_posY < 0} or {_posX > worldSize} or {_posY > worldSize} or {!(_radius in AREA_RADII)}) exitWith {};
    _newArea = [[_posX, _posY, 0], _radius];
};
if (_pos isNotEqualTo [] and {_newArea isEqualTo []}) exitWith {
    Error_3("Invalid mission area from %1: %2, radius %3", name _commander, _pos, _radius);
    false
};
if (_newArea isEqualTo A3A_missionArea) exitWith { false };

A3A_missionArea = _newArea;
publicVariable "A3A_missionArea";
call FUNC(missionAreaMarker);

private _title = localize "STR_A3A_Tasks_missionArea_title";
if (_newArea isEqualTo []) then {
    Info_1("Commander %1 moved the mission area back to the HQ", name _commander);
    [_title, format [localize "STR_A3A_Tasks_missionArea_reset", name _commander, distanceMission / 1000]] remoteExec ["A3A_fnc_customHint", 0];
} else {
    Info_3("Commander %1 set the mission area to %2, radius %3", name _commander, mapGridPosition (_newArea # 0), _radius);
    [_title, format [localize "STR_A3A_Tasks_missionArea_set", name _commander, mapGridPosition (_newArea # 0), _radius / 1000]] remoteExec ["A3A_fnc_customHint", 0];
};

// Missions outside the new area drop off the board, then it is topped up as for a fresh board
[0, 0, BOARD_START_PER_CATEGORY] spawn FUNC(boardUpdate);
true
