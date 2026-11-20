/*
Maintainer: Shoter
    Plague of the town crisis event: hurts the arms and legs of the given units and leaves them out of breath.
    The server sends it every few seconds to the machine where each unit inside the plague town is local, so the
    effect holds while the unit stays in the town. Out of the town nothing renews it, and the wounds can be treated
    and the breath comes back the normal way.
    Vanilla: arm and leg hit points at least 0.5 (limping, weapon sway), fatigue full, stamina empty.
    ACE medical: fractured arms and legs, which splints treat. ACE advanced fatigue: the player's reserves emptied.

Arguments:
    <ARRAY<OBJECT>> Units in the plague town. Units not local to this machine are skipped.

Return Value:
    <nil>

Scope: Any, local arguments
Environment: Unscheduled
Public: No

Example:
    [_units] remoteExecCall ["A3A_tasks_fnc_EVT_TownCrisis_sicken", _owner];
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

#define LIMB_DAMAGE 0.5

params [["_units", [], [[]]]];

private _aceMedical = !isNil "ace_medical_engine_fnc_updateDamageEffects";
private _aceFatigue = !isNil "ace_advanced_fatigue_anReserve";

{
    private _unit = _x;
    if (!local _unit or { !alive _unit }) then { continue };

    if (_aceMedical) then {
        // [head, body, left arm, right arm, left leg, right leg]: 1 fractured, -1 splinted, 0 healthy
        private _fractures = +(_unit getVariable ["ace_medical_fractures", [0, 0, 0, 0, 0, 0]]);
        if ((_fractures select [2, 4]) findIf { _x != 1 } != -1) then {
            for "_i" from 2 to 5 do { _fractures set [_i, 1] };
            _unit setVariable ["ace_medical_fractures", _fractures, true];
            [_unit] call ace_medical_engine_fnc_updateDamageEffects;
        };
    } else {
        {
            if ((_unit getHitPointDamage _x) < LIMB_DAMAGE) then { _unit setHitPointDamage [_x, LIMB_DAMAGE] };
        } forEach ["HitLegs", "HitHands"];
    };

    _unit setFatigue 1;
    _unit setStamina 0;
    if (_aceFatigue and { _unit == player }) then {
        ace_advanced_fatigue_anReserve = 0;
        ace_advanced_fatigue_anFatigue = 1;
    };
} forEach _units;
