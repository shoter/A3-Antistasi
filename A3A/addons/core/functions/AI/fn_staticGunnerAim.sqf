/*
Maintainer: Shoter
    Makes enemy AI less accurate while it mans a static weapon. A mounted gun has no recoil or sway,
    so even low-skill gunners are deadly with it: while on a static the unit gets 60% of its
    aimingAccuracy and 50% of its aimingSpeed. Leaving the static restores the original values.
    Mortars are left alone, their fire is handled by the artillery support code.
    Calling it again while the unit is on a static reapplies the reduction from the stored originals,
    which is needed after a general setSkill has overwritten the sub-skills.

Arguments:
    <OBJECT> Unit, must be local
    <OBJECT> Vehicle the unit is in now, objNull when it is on foot

Return Value:
    Nothing

Scope: Where the unit is local
Environment: Any
Public: No

Example:
    [_unit, objectParent _unit] call A3A_fnc_staticGunnerAim;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params ["_unit", "_vehicle"];

private _onStatic = !isNull _vehicle && {_vehicle isKindOf "StaticWeapon"} && {!(_vehicle isKindOf "StaticMortar")};
private _original = _unit getVariable "A3A_staticAimSkill";

if (_onStatic) then {
    if (isNil "_original") then {
        _original = [_unit skill "aimingAccuracy", _unit skill "aimingSpeed"];
        _unit setVariable ["A3A_staticAimSkill", _original];
    };
    _unit setSkill ["aimingAccuracy", (_original#0) * 0.6];
    _unit setSkill ["aimingSpeed", (_original#1) * 0.5];
} else {
    if (isNil "_original") exitWith {};
    _unit setSkill ["aimingAccuracy", _original#0];
    _unit setSkill ["aimingSpeed", _original#1];
    _unit setVariable ["A3A_staticAimSkill", nil];
};
