/*
Maintainer: Shoter
    Creates the commander rally flag object and its map marker at the given position.
    Sets and broadcasts A3A_deployedFlag. Does no permission or cooldown checks,
    use A3A_fnc_deployedFlagPlace for player requests.

Arguments:
    <POSITION> Position to place the flag at

Return Value:
    <OBJECT> The created flag

Scope: Server
Environment: Unscheduled
Public: No
Dependencies:

Example:
    [getPosATL player] call A3A_fnc_deployedFlagCreate;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if !(isServer) exitWith { Error("Attempted to call server function as non-server") };
params ["_pos"];

private _flagClass = FactionGet(reb,"flag");
private _emptyPos = _pos findEmptyPosition [0, 10, _flagClass];
if (_emptyPos isNotEqualTo []) then { _pos = _emptyPos };

private _flag = createVehicle [_flagClass, _pos, [], 0, "CAN_COLLIDE"];
_flag setPosATL [_pos#0, _pos#1, 0];
_flag setFlagTexture FactionGet(reb,"flagTexture");
_flag allowDamage false;
_flag setVariable ["A3A_deployedFlag", true, true];

// Keep globals and marker consistent if the flag is deleted by something else (Zeus, cleanup)
_flag addEventHandler ["Deleted", {
    if (A3A_deployedFlag isEqualTo (_this#0)) then { [objNull] call A3A_fnc_deployedFlagRemove };
}];

private _mrk = createMarker ["A3A_deployedFlagMrk", _pos];
_mrk setMarkerShape "ICON";
_mrk setMarkerType FactionGet(reb,"flagMarkerType");
_mrk setMarkerText (localize "STR_A3A_fn_base_deployedFlagCreate_marker");

A3A_deployedFlag = _flag;
publicVariable "A3A_deployedFlag";

// Remove action lives on the flag itself so the commander has to be at the flag (or the HQ flag) to remove it
[_flag] remoteExec ["A3A_fnc_deployedFlagAddAction", 0, "A3A_deployedFlagAction"];

Info_1("Deployed flag created at %1", _pos);
_flag;
