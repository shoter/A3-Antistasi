/*
Maintainer: Shoter
    Checks whether a garage entry can be sent on a garrison resupply run and returns its ammo points.
    Eligible: an ammo source that is not checked out, not locked by someone else, not a junkyard wreck
    and with ammo points left. Points come from the stored ammo cargo, or the default for the class when
    the truck has never been used.

Arguments:
    <ARRAY> Garage entry [displayName, class, lockUID, checkoutUID, state, lockName, customisation, lockTime]
    <STRING> UID of the requesting player, for the lock check
    <BOOL> True when the requesting player may override locks [DEFAULT = false]

Return Value:
    <NUMBER> Ammo points of the truck, -1 when the entry cannot be sent

Scope: Server
Environment: Any
Public: No
Dependencies:
    HR_GRG_fnc_isAmmoSource, A3A_resourceVehValues, A3A_fnc_junkyardClock

Example:
    [(HR_GRG_Vehicles # 6) get _vehUID, getPlayerUID _player, _player call HR_GRG_canOverrideLock] call A3A_fnc_garrisonResupplyTruckPoints;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_entry", [], [[]]], ["_uid", "", [""]], ["_canOverride", false, [false]]];
if (_entry isEqualTo []) exitWith { -1 };
_entry params ["", ["_class", "", [""]], ["_lockUID", "", [""]], ["_checkedOut", "", [""]], ["_state", [], [[]]]];

if (_checkedOut isNotEqualTo "") exitWith { -1 };
if !([_class] call HR_GRG_fnc_isAmmoSource) exitWith { -1 };
if (!(_lockUID in ["", _uid]) && { !_canOverride }) exitWith { -1 };

// Junkyard wreck: deadline lives in the damage state, see HR_GRG_fnc_getDamage / garage/Core/fn_reloadCategory.sqf
private _dmgStats = _state param [1, []];
private _junkUntil = if (_dmgStats isEqualType []) then { _dmgStats param [3, -1] } else { -1 };
if (_junkUntil isEqualType 0 && { _junkUntil > (call A3A_fnc_junkyardClock) }) exitWith { -1 };

// Ammo cargo is [points, aceCargo] once the truck has been garaged with the new rearm system, [] before that
private _cargo = _state param [3, []];
private _points = if (_cargo isEqualType [] && { _cargo isNotEqualTo [] }) then {
    _cargo # 0
} else {
    A3A_resourceVehValues get "rearm" getOrDefault [_class, 5000]
};
if (!(_points isEqualType 0) || { _points <= 0 }) exitWith { -1 };
_points
