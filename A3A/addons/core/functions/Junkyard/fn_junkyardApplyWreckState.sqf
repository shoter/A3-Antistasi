/*
Maintainer: Shoter
    Turns a freshly placed vehicle into a junkyard wreck: 10-20% health, every hitpoint yellow or red,
    low fuel and little or no ammo. Flags it as junk until A3A_junkyardJunkDuration seconds of campaign
    uptime have passed, during which HQ and garage never repair it for free.

    Must run where the vehicle is local. Call it synchronously right after placement, before the server
    garrisons the vehicle (which changes its owner). If the vehicle is not local it forwards itself to the owner.

Arguments:
    <OBJECT> Vehicle

Return Value:
    <nil>

Scope: Anywhere (executes on the vehicle owner)
Environment: Any
Public: No
Dependencies:

Example:
    [_vehicle] call A3A_fnc_junkyardApplyWreckState;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_vehicle", objNull, [objNull]]];
if (isNull _vehicle) exitWith {};
if !(local _vehicle) exitWith { [_vehicle] remoteExecCall ["A3A_fnc_junkyardApplyWreckState", _vehicle] };

_vehicle setVariable ["A3A_junkyardUntil", (call A3A_fnc_junkyardClock) + A3A_junkyardJunkDuration, true];

// The garage placer keeps damage disabled for the first half second after placement
private _damageWasAllowed = isDamageAllowed _vehicle;
if (!_damageWasAllowed) then { _vehicle allowDamage true };

_vehicle setDamage [0.8 + random 0.1, false];
{
    _vehicle setHitIndex [_forEachIndex, (0.5 + random 0.45) min 0.95, false];
} forEach ((getAllHitPointsDamage _vehicle) param [0, []]);

_vehicle setFuel (0.05 + random 0.1);
_vehicle setVehicleAmmo (selectRandom [0, 0, 0.1, 0.2]);

if (!_damageWasAllowed) then { _vehicle allowDamage false };     // placer re-enables it shortly
Info_2("Junkyard wreck state applied to %1, damage %2", typeOf _vehicle, damage _vehicle);
