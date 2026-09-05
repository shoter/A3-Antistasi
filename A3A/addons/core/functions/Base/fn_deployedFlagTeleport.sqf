/*
Maintainer: Shoter
    Teleports the local player (plus nearby squad AI and driven vehicle, as fast travel does) to the commander rally flag.
    Applies the generic fast travel blockers and the destination checks against the flag position.
    Free of charge and three times faster than regular fast travel.

Arguments:
    None

Return Value:
    <nil>

Scope: Clients
Environment: Scheduled
Public: No
Dependencies:

Example:
    [] spawn A3A_fnc_deployedFlagTeleport;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if (!hasInterface) exitWith {};

private _titleStr = localize "STR_A3A_fn_base_deployedFlag_title";
private _flag = A3A_deployedFlag;
if (isNull _flag) exitWith { [_titleStr, localize "STR_A3A_fn_base_deployedFlagTeleport_noFlag"] call A3A_fnc_customHint };

// Generic blockers only, destination checks are done below against the flag position
private _blockers = [player, player, nil] call A3A_fnc_canFastTravel;
if (_blockers isNotEqualTo []) exitWith {
    [_titleStr, localize ("STR_A3A_fn_dialogs_ftradio_" + (_blockers#0))] call A3A_fnc_customHint;
};

private _destPos = getPosATL _flag;
if ([_destPos] call A3A_fnc_enemyNearCheck) exitWith { [_titleStr, localize "STR_A3A_fn_dialogs_ftradio_no_attack2"] call A3A_fnc_customHint };
if (!(player call A3A_fnc_isMember || player == theBoss) && {!([_destPos] call A3A_fnc_playerLeashCheckPosition)}) exitWith {
    [_titleStr, localize "STR_A3A_fn_dialogs_ftradio_no_members"] call A3A_fnc_customHint;
};

[player, _destPos, player, true, 3, "flagTeleports"] call A3A_fnc_fastTravelMove;
