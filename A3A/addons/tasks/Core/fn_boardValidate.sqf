/*
Maintainer: Shoter
    Checks whether a mission board entry still makes sense.
    "gone": the mission no longer fits (location taken by the rebels, target destroyed, town no longer needs supplies,
    HQ moved away) and should leave the board.
    "busy": only when starting; the location is inside player spawn range right now (or players wait at the defector's
    car), the same rule the params getters apply. The mission stays on the board and can be taken later.

Arguments:
    <HASHMAP> Board entry, see A3A_tasks_fnc_boardGenerate
    <BOOL> Check the extra conditions for starting the mission now [DEFAULT = false]

Return Value:
    <STRING> "" when valid, otherwise "gone" or "busy"

Scope: Server
Environment: Any
Public: No

Example:
    if (([_entry, true] call A3A_tasks_fnc_boardValidate) == "") then { ... };
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

params ["_entry", ["_starting", false]];

private _task = _entry get "task";
private _marker = _entry get "marker";
private _args = _entry get "args";
private _fnc_rebel = { sidesX getVariable [_this, sideUnknown] == teamPlayer };

private _gone = call {
    if (markerPos _marker distance2D markerPos "Synd_HQ" > distanceMission + 1000) exitWith { true };
    switch (_task) do {
        case "SUP_Supplies": { _marker in destroyedSites or { (A3A_cityData getVariable _marker) select 1 >= 80 } };
        case "LOG_Gunshop": { false };                  // meets in rebel towns too
        case "SUP_Elderly": { _marker in destroyedSites or { !alive (_args # 1) } };     // any town, the house must still stand
        case "LOG_Weapons": { (_args # 2) call _fnc_rebel };
        case "AS_Collaborator": { _marker call _fnc_rebel or { (_args # 3) call _fnc_rebel } };        // town, destination outpost
        case "DES_Antenna";
        case "SUP_PoliceStation": { _marker call _fnc_rebel or { !alive (_args # 1) } };
        case "AS_Traitor";
        case "convoy": { _marker call _fnc_rebel or { (_args # 1) call _fnc_rebel } };      // traitor's airbase, convoy start
        default { _marker call _fnc_rebel };
    };
};
if (_gone) exitWith { "gone" };
if (!_starting) exitWith { "" };

if (_task in ["AS_Collaborator", "AS_Official", "AS_Traitor", "LOG_Gunshop", "RES_Prisoners", "RES_Refugees"] and { spawner getVariable [_marker, 2] == 0 }) exitWith { "busy" };
if (_task == "SUP_Elderly" and { (allPlayers - entities "HeadlessClient_F") inAreaArray [getPosATL (_args # 1), 300, 300] isNotEqualTo [] }) exitWith { "busy" };
if (_task == "RES_Defector" and { (allPlayers - entities "HeadlessClient_F") inAreaArray [_args # 1, 500, 500] isNotEqualTo [] }) exitWith { "busy" };
"";
