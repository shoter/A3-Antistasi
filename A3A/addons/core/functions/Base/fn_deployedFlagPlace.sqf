/*
Maintainer: Shoter
    Handles a commander request to deploy the rally flag in front of them.
    Validates commander status, state and the redeploy cooldown.
    If a flag already exists and the cooldown has passed, the old flag is replaced.

Arguments:
    <OBJECT> Player requesting the deployment

Return Value:
    <nil>

Scope: Server
Environment: Unscheduled
Public: No
Dependencies:

Example:
    [player] remoteExecCall ["A3A_fnc_deployedFlagPlace", 2];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if !(isServer) exitWith { Error("Attempted to call server function as non-server") };
params [["_player", objNull, [objNull]]];

if (isNull _player or {_player != theBoss}) exitWith { Error_1("Deploy flag requested by non-commander %1", name _player) };
if (!alive _player or vehicle _player != _player or A3A_petrosMoving) exitWith { Info_1("Deploy flag request by %1 rejected: state check failed", name _player) };
if (!isNull A3A_deployedFlag and {serverTime - A3A_deployedFlagTime < A3A_deployedFlagCooldown}) exitWith { Info_1("Deploy flag request by %1 rejected: cooldown", name _player) };

// Replace existing flag, if any. Marker deletion is a safety net in case the flag vanished without the Deleted EH firing.
if (!isNull A3A_deployedFlag) then { [objNull] call A3A_fnc_deployedFlagRemove };
deleteMarker "A3A_deployedFlagMrk";

[_player getPos [3, getDir _player]] call A3A_fnc_deployedFlagCreate;

A3A_deployedFlagTime = serverTime;
publicVariable "A3A_deployedFlagTime";

[localize "STR_A3A_fn_base_deployedFlag_title", localize "STR_A3A_fn_base_deployedFlagPlace_deployed"] remoteExec ["A3A_fnc_customHint", 0];
Info_1("Deployed flag placed by %1", name _player);
