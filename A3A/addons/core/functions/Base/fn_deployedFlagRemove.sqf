/*
Maintainer: Shoter
    Removes the commander rally flag and its map marker, and broadcasts A3A_deployedFlag as objNull.
    Does not reset A3A_deployedFlagTime: the redeploy cooldown only gates replacing an existing flag.

Arguments:
    <OBJECT> Player requesting the removal. objNull for internal calls (no permission check, no hint) [DEFAULT = objNull]

Return Value:
    <nil>

Scope: Server
Environment: Unscheduled
Public: No
Dependencies:

Example:
    [player] remoteExecCall ["A3A_fnc_deployedFlagRemove", 2];
    [objNull] call A3A_fnc_deployedFlagRemove;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if !(isServer) exitWith { Error("Attempted to call server function as non-server") };
params [["_player", objNull, [objNull]]];

if (!isNull _player and {_player != theBoss}) exitWith { Error_1("Remove flag requested by non-commander %1", name _player) };

private _flag = A3A_deployedFlag;

// Clear the global before deleting so the flag's Deleted EH does not recurse
A3A_deployedFlag = objNull;
publicVariable "A3A_deployedFlag";

deleteMarker "A3A_deployedFlagMrk";
if (!isNull _flag) then { deleteVehicle _flag };

if (!isNull _player) then {
    [localize "STR_A3A_fn_base_deployedFlag_title", localize "STR_A3A_fn_base_deployedFlagRemove_removed"] remoteExec ["A3A_fnc_customHint", 0];
    Info_1("Deployed flag removed by %1", name _player);
} else {
    Info("Deployed flag removed");
};
