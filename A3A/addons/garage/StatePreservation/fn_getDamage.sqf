/*
    Author: [Håkon]
    [Description]


    Arguments:
        0. <Object> Vehicle to get damage state from

    Return Value:
        <Array> [
            <Scalar> Overall damage
            <Array> Optional: Hitpoint damage
            <Scalar> Repair cargo
        ] Damage state
        or 
        <Scalar> Overall damage

    Scope: Any
    Environment: Any
    Public: Yes
    Dependencies:

    Example:

    License: APL-ND
*/
params ["_vehicle"];
private _restoreState = [0,1] select (HR_GRG_hasRepairSource && !HR_GRG_ServiceDisabled_Repair);
private _isJunkyard = [_vehicle] call A3A_fnc_junkyardIsJunk;     // Antistasi junkyard wrecks: full state always kept, not auto-repaired until the deadline

private _output = [damage _vehicle min 0.89];
private _hitPointDamage = getAllHitPointsDamage _vehicle;
if (_hitPointDamage isNotEqualTo []) then { //ensure it has hitpoints
    // Skip storing hitpoints if damage is low or we can repair it
    if (!_isJunkyard and HR_GRG_reduceState and (selectMax (_hitPointDamage#2) < 0.15 or _restoreState == 1)) exitWith {};
    _output pushBack _hitPointDamage#2;
};

// Set repair cargo only if it exists
if (getNumber (configOf _vehicle/"transportRepair") > 0) then { _output set [2, getRepairCargo _vehicle] };

// Junkyard deadline (campaign clock seconds) travels with the damage state so it survives garaging and saves
if (_isJunkyard) then {
    if (count _output == 1) then { _output pushBack [] };
    if (count _output == 2) then { _output pushBack -1 };
    _output set [3, _vehicle getVariable "A3A_junkyardUntil"];
};

// If we only have overall damage, just return that
if (count _output == 1) exitWith { _output#0 };
_output;
