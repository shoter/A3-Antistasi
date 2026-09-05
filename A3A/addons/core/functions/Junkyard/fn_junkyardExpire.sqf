/*
Maintainer: Shoter
    Clears the junk status of spawned vehicles whose deadline has passed and tells the players.
    Vehicles stored in the garage or in a garrison save are checked when their state is applied instead.

Arguments:
    None

Return Value:
    <nil>

Scope: Server
Environment: Any
Public: No
Dependencies: A3A_fnc_junkyardClock

Example:
    call A3A_fnc_junkyardExpire;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if !(isServer) exitWith { Error("Attempted to call server function as non-server") };

private _now = call A3A_fnc_junkyardClock;
{
    if ((_x getVariable ["A3A_junkyardUntil", -1]) > _now) then { continue };
    _x setVariable ["A3A_junkyardUntil", nil, true];
    private _displayName = getText (configFile >> "CfgVehicles" >> typeOf _x >> "displayName");
    [localize "STR_A3A_fn_junkyard_title", format [localize "STR_A3A_fn_junkyard_expired", _displayName]] remoteExec ["A3A_fnc_customHint", 0];
    Info_1("Junkyard: %1 is no longer junk", typeOf _x);
} forEach (vehicles select { !isNil { _x getVariable "A3A_junkyardUntil" } });
