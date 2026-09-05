/*
Maintainer: Shoter
    Removes every upgrade of a town, used when the town falls to the enemy or is destroyed.
    Idempotent: a town without upgrades is a no-op, so the punishment loss path may call it twice.
    Sends one combined notification to the rebels.

Arguments:
    <STRING> City marker name
    <STRING> Reason, notification key STR_A3A_fn_townUpgrades_lostAll_<reason>: "flipped" or "destroyed" [DEFAULT = "flipped"]

Return Value:
    <nil>

Scope: Server
Environment: Unscheduled
Public: No
Dependencies:
    <HASHMAP> A3A_cityInvest, A3A_townUpgradeOrder

Example:
    ["Kavala", "flipped"] call A3A_fnc_townUpgradeClearCity;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if !(isServer) exitWith { Error("Attempted to call server function as non-server") };
params [["_city", "", [""]], ["_reason", "flipped", [""]]];

if (isNil "A3A_cityInvest") exitWith {};        // called from destroyCity during init before the data exists
private _installed = keys (A3A_cityInvest getOrDefault [_city, createHashMap]);
if (_installed isEqualTo []) exitWith {};

private _ids = A3A_townUpgradeOrder select { _x in _installed };
{ [_city, _x, "silent"] call A3A_fnc_townUpgradeRemove } forEach _ids;

private _names = _ids apply { localize format ["STR_A3A_fn_townUpgrades_name_%1", _x] };
[localize "STR_A3A_fn_townUpgrades_title", format [localize ("STR_A3A_fn_townUpgrades_lostAll_" + _reason), _city, _names joinString ", "]] remoteExec ["A3A_fnc_customHint", teamPlayer];
Info_3("Town upgrades %1 in %2 cleared (%3)", _ids, _city, _reason);
