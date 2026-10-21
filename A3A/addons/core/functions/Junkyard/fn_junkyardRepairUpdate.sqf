/*
Maintainer: Shoter
    Junkyard repair shop upkeep, run by the junkyard loop: removes repaired vehicles nobody bought within
    A3A_junkyardRepairBuyWindow and tells the players about vehicles that finished their repair since the last call.

Arguments:
    <SCALAR> Campaign clock of the previous call, see A3A_fnc_junkyardClock

Return Value:
    <SCALAR> Campaign clock of this call, pass it to the next one

Scope: Server
Environment: Any
Public: No
Dependencies: A3A_fnc_junkyardClock

Example:
    _lastRepairCheck = [_lastRepairCheck] call A3A_fnc_junkyardRepairUpdate;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if !(isServer) exitWith { Error("Attempted to call server function as non-server"); 0 };
params [["_lastCheck", 0, [0]]];

private _now = call A3A_fnc_junkyardClock;

private _expired = A3A_junkyardRepairs select { _x#5 <= _now };
if (_expired isNotEqualTo []) then {
    A3A_junkyardRepairs = A3A_junkyardRepairs - _expired;
    publicVariable "A3A_junkyardRepairs";
    Info_1("Junkyard repair: removed unsold %1", _expired apply { _x#1 });
};

private _finished = A3A_junkyardRepairs select { _x#4 > _lastCheck and _x#4 <= _now };
if (_finished isNotEqualTo []) then {
    private _text = if (count _finished == 1) then {
        private _displayName = getText (configFile >> "CfgVehicles" >> (_finished # 0 # 1) >> "displayName");
        format [localize "STR_A3A_fn_junkyard_repair_readyOne", _displayName, _finished # 0 # 2]
    } else {
        format [localize "STR_A3A_fn_junkyard_repair_readyMany", count _finished]
    };
    [localize "STR_A3A_fn_junkyard_repair_title", _text] remoteExec ["A3A_fnc_customHint", 0];
};

_now;
