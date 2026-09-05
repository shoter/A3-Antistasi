/*
Maintainer: Shoter
    Unloads the air taxi passengers, run where the units are local.
    Works for a landed and for a hovering helicopter; units that end up in the air
    (failed hover) are placed on the ground next to the drop position.

Arguments:
    <OBJECT> Helicopter
    <POSITION> Ground position under the helicopter, used as a safety net

Return Value:
    <nil>

Scope: Any
Environment: Unscheduled
Public: No
Dependencies:

Example:
    [_heli, _groundPos] remoteExec ["A3A_fnc_airTaxiUnload", [2] + (_passengers select { isPlayer _x })];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_heli", objNull, [objNull]], ["_groundPos", [0,0,0], [[]]]];
if (isNull _heli) exitWith {};

{
    if (!local _x || { _x getVariable ["A3A_airTaxiCrew", false] }) then { continue };
    unassignVehicle _x;
    moveOut _x;
    if ((getPosATL _x) # 2 > 4) then {
        private _pos = _groundPos findEmptyPosition [0, 20, typeOf _x];
        if (_pos isEqualTo []) then { _pos = _groundPos getPos [5 + random 10, random 360] };
        _x setPosATL _pos;
    };
    if (!isPlayer _x) then { _x doFollow leader _x };
} forEach crew _heli;
