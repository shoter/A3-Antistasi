/*
Maintainer: Shoter
    Debug helper: finishes every running repair in the junkyard repair shop on request of a logged-in or voted admin.
    The finished vehicles get the normal buy window from now on. An open Junkyard dialog picks up the change by itself.

Arguments:
    <OBJECT> Requesting player, must be admin (checked server-side)

Return Value:
    <nil>

Scope: Server
Environment: Unscheduled
Public: No
Dependencies: A3A_fnc_isClientAdmin, A3A_fnc_junkyardClock

Example:
    [player] remoteExecCall ["A3A_fnc_junkyardRepairAdminFinish", 2];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if !(isServer) exitWith { Error("Attempted to call server function as non-server") };
params [["_player", objNull, [objNull]]];
if (isNull _player) exitWith {};
if !([_player] call A3A_fnc_isClientAdmin) exitWith { Error_1("Junkyard repair finish requested by non-admin %1", name _player) };

private _now = call A3A_fnc_junkyardClock;
private _finished = 0;
{
    if (_x#4 <= _now) then { continue };
    _x set [4, _now];
    _x set [5, _now + A3A_junkyardRepairBuyWindow];
    _finished = _finished + 1;
} forEach A3A_junkyardRepairs;
publicVariable "A3A_junkyardRepairs";

Info_2("Junkyard repair: admin %1 finished %2 repairs", name _player, _finished);
