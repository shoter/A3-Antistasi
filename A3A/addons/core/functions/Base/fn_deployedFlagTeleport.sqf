/*
Maintainer: Shoter
    Teleports the local player and their squad AI to the commander rally flag, the way fast travel does it: black
    screen with a countdown, then everyone is set down at the destination. Only people on foot travel: the player has
    to be on foot and only the squad AI on foot within 50 m of the player (when the player leads the group) come along.
    Price, travel time and enemy presence come from A3A_fnc_deployedFlagTeleportInfo and are meant to have been shown
    and accepted in the confirmation dialog on the HQ flag (A3A_GUI_fnc_deployedFlagDialog) before this runs.

    Without enemies at the flag the squad lands right at the flag. With enemies at the flag everyone lands scattered
    50-100 m around it, each on their own spot. The enemy presence decided at the start is what counts even if the
    situation at the flag changes during the countdown, since the price was paid for it.

Arguments:
    None

Return Value:
    <nil>

Scope: Clients
Environment: Scheduled
Public: No
Dependencies:
    A3A_fnc_deployedFlagTeleportInfo, A3A_fnc_resourcesPlayer, A3A_fnc_playerLeashRefresh

Example:
    [] spawn A3A_fnc_deployedFlagTeleport;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

#define SQUAD_RADIUS 50
#define SCATTER_MIN 50
#define SCATTER_MAX 100

if (!hasInterface) exitWith {};

private _titleStr = localize "STR_A3A_fn_base_deployedFlag_title";
([] call A3A_fnc_deployedFlagTeleportInfo) params ["_destPos", "_distance", "_enemyPresent", "_cost", "_travelTime", "_squadCount", "_blockers"];
if (_blockers isNotEqualTo []) exitWith { [_titleStr, _blockers # 0] call A3A_fnc_customHint };
if (player getVariable ["moneyX", 0] < _cost) exitWith { [_titleStr, localize "STR_A3A_fn_base_deployedFlagTeleport_noMoney"] call A3A_fnc_customHint };

[-_cost] call A3A_fnc_resourcesPlayer;
Info_4("Rally flag teleport started by %1: %2 m, enemies %3, cost %4", name player, round _distance, _enemyPresent, _cost);

openMap false;
disableUserInput true;
cutText [format [localize "STR_A3A_fn_dialogs_fastTravelRadio_begin", ([[_travelTime] call A3A_fnc_secondsToTimeSpan,0,0,false,2] call A3A_fnc_timeSpan_format)], "BLACK", 1];
while {_travelTime >= 1} do {
    sleep 1;
    _travelTime = _travelTime - 1;
    cutText [format [localize "STR_A3A_fn_dialogs_fastTravelRadio_begin", ([[_travelTime] call A3A_fnc_secondsToTimeSpan,0,0,false,2] call A3A_fnc_timeSpan_format)], "BLACK", 0.001];
};

// Who comes along is decided now, after the countdown, as fast travel does. Only squad AI on foot, no vehicles.
private _ftUnits = [player];
if (player == leader group player) then {
    _ftUnits = ((units group player inAreaArray [getPosATL player, SQUAD_RADIUS, SQUAD_RADIUS]) select { !isPlayer _x && {alive _x} && {vehicle _x == _x} }) + [player];
};

// The commander may have moved the flag during the countdown: follow it. If it is gone, the old spot will do.
if (!isNull A3A_deployedFlag) then { _destPos = getPosATL A3A_deployedFlag };

{
    private _unitPos = if (_enemyPresent) then {
        private _spot = _destPos getPos [SCATTER_MIN + random (SCATTER_MAX - SCATTER_MIN), random 360];
        private _emptyPos = _spot findEmptyPosition [0, 10, typeOf _x];
        if (_emptyPos isEqualTo []) then { _spot } else { _emptyPos };
    } else {
        private _emptyPos = _destPos findEmptyPosition [2, 15, typeOf _x];
        if (_emptyPos isEqualTo []) then { _destPos getPos [3 + random 10, random 360] } else { _emptyPos };
    };
    _x setPosATL _unitPos;
    if (!isPlayer _x and !(_x getVariable ["incapacitated", false])) then {
        _x setVariable ["rearming", false];
        _x doWatch objNull;
        _x doFollow leader _x;
    };
} forEach _ftUnits;

// Player statistics: the move went through
[[player] call A3A_fnc_playerStats_getUID, [["flagTeleports", 1]]] remoteExecCall ["A3A_fnc_playerStats_add", 2];

disableUserInput false;
cutText [localize "STR_A3A_fn_dialogs_fastTravelRadio_end", "BLACK IN", 1];
[] call A3A_fnc_playerLeashRefresh;
