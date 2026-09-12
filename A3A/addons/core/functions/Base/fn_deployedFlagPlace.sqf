/*
Maintainer: Shoter
    Handles a commander request to deploy the rally flag in front of them, from the Commander tab of the Battle Command menu.
    Validates commander status and state. Only one flag can exist at a time: when a flag is already deployed it is
    removed and the new one takes its place, there is no limit on how often the commander does this.
    Removing the flag without placing a new one is done at the flag or at the HQ flag (A3A_fnc_deployedFlagRemove).

Arguments:
    <OBJECT> Player requesting the deployment

Return Value:
    <nil>

Scope: Server
Environment: Unscheduled
Public: No
Dependencies:
    A3A_fnc_deployedFlagCreate, A3A_fnc_deployedFlagRemove

Example:
    [player] remoteExecCall ["A3A_fnc_deployedFlagPlace", 2];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if !(isServer) exitWith { Error("Attempted to call server function as non-server") };
params [["_player", objNull, [objNull]]];

if (isNull _player or {_player != theBoss}) exitWith { Error_1("Deploy flag requested by non-commander %1", name _player) };
if (!alive _player or vehicle _player != _player or A3A_petrosMoving) exitWith { Info_1("Deploy flag request by %1 rejected: state check failed", name _player) };

// One flag at a time: the previous one goes quietly, the hint below tells everyone where the flag is now
private _moved = !isNull A3A_deployedFlag;
if (_moved) then { [objNull] call A3A_fnc_deployedFlagRemove };

// Safety net in case the flag vanished without the Deleted EH firing and left its marker behind
deleteMarker "A3A_deployedFlagMrk";

[_player getPos [3, getDir _player]] call A3A_fnc_deployedFlagCreate;

private _hintKey = ["STR_A3A_fn_base_deployedFlagPlace_deployed", "STR_A3A_fn_base_deployedFlagPlace_moved"] select _moved;
[localize "STR_A3A_fn_base_deployedFlag_title", localize _hintKey] remoteExec ["A3A_fnc_customHint", 0];
private _verb = ["placed", "moved"] select _moved;
Info_2("Deployed flag %1 by %2", _verb, name _player);
