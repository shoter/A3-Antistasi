/*
Maintainer: Shoter
    Debug helper: restocks the junkyard immediately on request of a logged-in or voted admin,
    then reopens the Junkyard dialog for that player.

Arguments:
    <OBJECT> Requesting player, must be admin (checked server-side)

Return Value:
    <nil>

Scope: Server
Environment: Unscheduled
Public: No
Dependencies: A3A_fnc_isClientAdmin, A3A_fnc_junkyardRefresh

Example:
    [player] remoteExecCall ["A3A_fnc_junkyardAdminRefresh", 2];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if !(isServer) exitWith { Error("Attempted to call server function as non-server") };
params [["_player", objNull, [objNull]]];
if (isNull _player) exitWith {};
if !([_player] call A3A_fnc_isClientAdmin) exitWith { Error_1("Junkyard refresh requested by non-admin %1", name _player) };

Info_1("Junkyard refresh forced by admin %1", name _player);
[_player] spawn {
    params ["_player"];
    call A3A_fnc_junkyardRefresh;
    { createDialog "A3A_JunkyardDialog" } remoteExec ["call", _player];
};
