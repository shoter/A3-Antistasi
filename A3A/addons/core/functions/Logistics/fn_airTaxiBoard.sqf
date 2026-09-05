/*
Maintainer: Shoter
    Boarding orders for the air taxi passengers, run where the units are local.
    Players get a countdown hint, AI squad members are ordered into the cargo seats.
    Safe to run more than once.

Arguments:
    <OBJECT> Helicopter
    <ARRAY<OBJECT>> Units expected to board
    <NUMBER> serverTime at which the helicopter leaves

Return Value:
    <nil>

Scope: Any
Environment: Unscheduled
Public: No
Dependencies:

Example:
    [_heli, _expected, serverTime + 60] remoteExec ["A3A_fnc_airTaxiBoard", [2] + (_expected select { isPlayer _x })];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_heli", objNull, [objNull]], ["_units", [], [[]]], ["_endTime", 0, [0]]];
if (isNull _heli) exitWith {};

{
    if (isNull _x || { !local _x } || { !alive _x }) then { continue };
    if (isPlayer _x) then {
        if (hasInterface && { _x == player }) then {
            [localize "STR_A3A_fn_logistics_airTaxi_title", localize "STR_A3A_fn_logistics_airTaxi_boarding", _endTime, _heli, 300] spawn A3A_fnc_customHintCountdown;
        };
    } else {
        _x assignAsCargo _heli;
        [_x] orderGetIn true;
    };
} forEach _units;
