/*
Maintainer: Shoter
    Turns a freshly placed vehicle into a junkyard wreck: 10-20% health, every hitpoint yellow or red,
    low fuel and little or no ammo. Flags it as junk until A3A_junkyardJunkDuration seconds of campaign
    uptime have passed, during which HQ and garage never repair it for free.
    Waits a moment because the garage placer re-enables damage half a second after placement.

Arguments:
    <OBJECT> Vehicle, must be local to this machine

Return Value:
    <nil>

Scope: Clients (vehicle owner)
Environment: Scheduled
Public: No
Dependencies:

Example:
    [_vehicle] spawn A3A_fnc_junkyardApplyWreckState;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_vehicle", objNull, [objNull]]];
if (isNull _vehicle) exitWith {};

sleep 1;
if (isNull _vehicle) exitWith {};
if !(local _vehicle) exitWith { Error_1("Junkyard wreck state requested for non-local vehicle %1", _vehicle) };

_vehicle setVariable ["A3A_junkyardUntil", (call A3A_fnc_junkyardClock) + A3A_junkyardJunkDuration, true];

_vehicle setDamage [0.8 + random 0.1, false];
{
    _vehicle setHitIndex [_forEachIndex, (0.5 + random 0.45) min 0.95, false];
} forEach ((getAllHitPointsDamage _vehicle) param [0, []]);

_vehicle setFuel (0.05 + random 0.1);
_vehicle setVehicleAmmo (selectRandom [0, 0, 0.1, 0.2]);
