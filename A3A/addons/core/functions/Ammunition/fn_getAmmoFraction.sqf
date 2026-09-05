/*
Maintainer: Shoter
    Returns how full a vehicle's turret magazines are, as a fraction of its default (config) loadout.
    Works on a live object or on a stored garage state entry, so it can be used for spawned and despawned
    garrison vehicles alike. Pylon and fake magazines are ignored, like the rearm dialog does.

Arguments:
    <OBJECT or STRING> Vehicle object, or vehicle classname when only a stored state is available
    <ARRAY> Garage state [fuel, damage, ammoData, ammoCargo] as stored by HR_GRG_fnc_getState, used when the first
            argument is a classname. nil or [] means the vehicle was never touched, so it is full [DEFAULT = nil]

Return Value:
    <NUMBER> 0..1 fraction of the default rounds still loaded, -1 when the class has no magazines to track

Scope: Any
Environment: Any
Public: No
Dependencies:
    HR_GRG_fnc_getDefaultMags

Example:
    [cursorObject] call A3A_fnc_getAmmoFraction;
    ["B_HMG_01_high_F", _vehEntry # 2] call A3A_fnc_getAmmoFraction;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_vehicle", objNull, [objNull, ""]], ["_state", [], [[]]]];

private _blacklistMags = ["FakeWeapon", "FakeMagazine"];
private _class = if (_vehicle isEqualType objNull) then { typeOf _vehicle } else { _vehicle };
if (_class == "") exitWith { -1 };

// Default loadout, combined per magazine type and turret
private _maxRounds = 0;
private _defaultKeys = [];
{
    _x params ["_mag", "_turret", "_rounds"];
    if (_mag in _blacklistMags) then { continue };
    _maxRounds = _maxRounds + _rounds;
    _defaultKeys pushBackUnique (toLower _mag + str _turret);
} forEach ([_class] call HR_GRG_fnc_getDefaultMags);
if (_maxRounds == 0) exitWith { -1 };

private _rounds = call {
    // Live object: count what is loaded in the default magazine slots
    if (_vehicle isEqualType objNull) exitWith {
        private _total = 0;
        {
            _x params ["_mag", "_turret", "_count"];
            if ((toLower _mag + str _turret) in _defaultKeys) then { _total = _total + _count };
        } forEach magazinesAllTurrets _vehicle;
        _total
    };

    // Stored state: nothing recorded means the vehicle has never been used
    if (_state isEqualTo []) exitWith { _maxRounds };
    private _ammoData = _state param [2, []];
    if (_ammoData isEqualType 0) exitWith { _ammoData * _maxRounds };
    if (_ammoData isEqualTo []) exitWith { _maxRounds };

    private _total = 0;
    {
        _x params ["_isPylon", "_data"];
        if (_isPylon) then { continue };
        _data params ["_mag", "_turret", "_count"];
        if ((toLower _mag + str _turret) in _defaultKeys) then { _total = _total + _count };
    } forEach _ammoData;
    _total
};

(_rounds / _maxRounds) max 0 min 1
