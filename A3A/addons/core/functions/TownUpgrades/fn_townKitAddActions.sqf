/*
Maintainer: Shoter
    Adds the local player actions to a town upgrade kit crate: carry, install at the bound town, return at HQ.
    Called by the server through remoteExec with a JIP id when the crate is created, so late joiners get it too.
    The crate is not a utility item, so the carry action is added here instead of A3A_fnc_initObjectRemote.

Arguments:
    <OBJECT> The crate

Return Value:
    <nil>

Scope: Clients
Environment: Any
Public: No
Dependencies:

Example:
    [_crate] remoteExec ["A3A_fnc_townKitAddActions", 0, _jipKey];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if (!hasInterface) exitWith {};
params [["_crate", objNull, [objNull]]];
if (isNull _crate) exitWith {};

(_crate getVariable ["A3A_townKit", ["", ""]]) params ["_id", "_city"];
if (_id == "") exitWith { Error_1("Town kit crate %1 carries no kit data", _crate) };
private _name = localize format ["STR_A3A_fn_townUpgrades_name_%1", _id];

// Carry, same as utility items
_crate addAction [
    localize "STR_A3A_fn_UtilItem_initObjRem_addact_carry",
    A3A_fnc_carryItem,
    _crate, 1.5, true, true, "",
    "!(call A3A_fnc_isCarrying) and (vehicle _this == _this) and (isNull attachedTo _originalTarget)", 8
];

// Install at the bound town. Shown when the crate is on the ground near the town centre, the placer checks the exact radius.
_crate addAction [
    format [localize "STR_A3A_fn_townUpgrades_action_install", _name],
    { [_this # 0] spawn A3A_fnc_townKitInstallStart },
    nil, 1.6, true, true, "",
    "(isNull attachedTo _originalTarget) and {_originalTarget distance2D markerPos ((_originalTarget getVariable ['A3A_townKit', ['', '']]) # 1) < 250}", 8
];

// Return at HQ for a refund, commander only
_crate addAction [
    localize "STR_A3A_fn_townUpgrades_action_return",
    { [_this # 0, player] remoteExecCall ["A3A_fnc_townKitReturn", 2] },
    nil, 1.4, true, true, "",
    "(_this == theBoss) and (isNull attachedTo _originalTarget) and (_originalTarget inArea 'Synd_HQ')", 8
];
