/*
Maintainer: Shoter
    Adds the "Remove rally flag" action to the commander rally flag on the local client.
    Called by the server through remoteExec with a JIP id whenever a flag is created, so late joiners get it too.
    Together with the same action on the HQ flag (initClient) this is the only way to remove a deployed flag.

Arguments:
    <OBJECT> The rally flag

Return Value:
    <nil>

Scope: Clients
Environment: Any
Public: No
Dependencies:

Example:
    [_flag] remoteExec ["A3A_fnc_deployedFlagAddAction", 0, "A3A_deployedFlagAction"];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if (!hasInterface) exitWith {};
params [["_flag", objNull, [objNull]]];
if (isNull _flag) exitWith {};

_flag addAction [localize "STR_A3A_fn_init_installClientEH_removeFlag", {
    [player] remoteExecCall ["A3A_fnc_deployedFlagRemove", 2];
}, nil, 0, false, true, "", "(_this == theBoss) and (_target == A3A_deployedFlag)", 4];
