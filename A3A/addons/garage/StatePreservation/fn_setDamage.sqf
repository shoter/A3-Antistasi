/*
    Author: [Håkon]
    [Description]


    Arguments:
        0. <Object> Vehicle to set damage state off
        1. <Array> [
            <Scalar> Overall damage
            <Array> Hitpoint damage
            <Scalar> Repair cargo
            <Scalar> Optional: Antistasi junkyard deadline (campaign clock seconds), blocks the auto-repair on checkout until then
        ] Damage state
        or
        <Scalar> Overall damage

    Return Value: <nil>

    Scope: Any
    Environment: Any
    Public: Yes
    Dependencies:

    Example:

    License: APL-ND
*/
params ["_vehicle", "_dmgStats"];
if !(local _vehicle) exitWith {};

private _restoreState = [0,1] select (HR_GRG_hasRepairSource && !HR_GRG_ServiceDisabled_Repair);
if (_dmgStats isEqualType 0) exitWith { _vehicle setDamage ([_dmgStats, 0] # _restoreState) };

_dmgStats params [["_dmg",0,[0]], ["_hitDmg", [], [[]]], ["_repairCargo", -1, [0]], ["_junkUntil", -1, [0, false]]];
if (_junkUntil isEqualType true) then { _junkUntil = [-1, (call A3A_fnc_junkyardClock) + A3A_junkyardJunkDuration] select _junkUntil };   // older bool format
if (_junkUntil > (call A3A_fnc_junkyardClock)) then {
    // Antistasi junkyard wreck, not repaired for free until the deadline
    _restoreState = 0;
    _vehicle setVariable ["A3A_junkyardUntil", _junkUntil, true];
};
_vehicle setDamage ([_dmg, 0] # _restoreState);

if (_hitDmg#0 isEqualTo []) then {_hitDmg = _hitDmg#1}; //temp compat while testing, old had selection names we no longer care about those
{
    _vehicle setHitIndex [_forEachIndex, [_x, 0] # _restoreState , false];
} forEach _hitDmg;

_vehicle setRepairCargo _repairCargo;
