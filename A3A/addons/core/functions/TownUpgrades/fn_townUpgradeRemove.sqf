/*
Maintainer: Shoter
    Removes a town upgrade: registry entry (broadcast), map marker, client actions and the prop itself.
    This is the only removal path, the prop's Killed/Deleted handlers, sabotage, dismantling and town loss all end here.
    Notifies the rebels unless the reason is "silent".

Arguments:
    <STRING> City marker name
    <STRING> Upgrade id
    <STRING> Reason, used for the notification key STR_A3A_fn_townUpgrades_lost_<reason>: "lost", "sabotage", "dismantled" or "silent" [DEFAULT = "lost"]

Return Value:
    <BOOL> True when something was removed

Scope: Server
Environment: Unscheduled
Public: No
Dependencies:
    <HASHMAP> A3A_cityInvest, A3A_townUpgradeObjects

Example:
    ["Kavala", "clinic", "sabotage"] call A3A_fnc_townUpgradeRemove;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if !(isServer) exitWith { Error("Attempted to call server function as non-server"); false };
params [["_city", "", [""]], ["_id", "", [""]], ["_reason", "lost", [""]]];

private _key = _city + "|" + _id;
private _prop = A3A_townUpgradeObjects getOrDefault [_key, objNull];
private _cityUpgrades = A3A_cityInvest getOrDefault [_city, createHashMap];
if (!(_id in _cityUpgrades) and isNull _prop) exitWith { false };

// Registry first so the prop's Deleted handler does not re-enter
_cityUpgrades deleteAt _id;
if (count _cityUpgrades == 0) then { A3A_cityInvest deleteAt _city } else { A3A_cityInvest set [_city, _cityUpgrades] };
publicVariable "A3A_cityInvest";
A3A_townUpgradeObjects deleteAt _key;

deleteMarker format ["A3A_townUpg_%1_%2", _city, _id];
remoteExec ["", format ["A3A_townUpgAct_%1_%2", _city, _id]];
if (!isNull _prop) then { deleteVehicle _prop };

if (_id == "militia") then { [_city] call A3A_fnc_mrkUpdate };

if (_reason != "silent") then {
    private _name = localize format ["STR_A3A_fn_townUpgrades_name_%1", _id];
    [localize "STR_A3A_fn_townUpgrades_title", format [localize ("STR_A3A_fn_townUpgrades_lost_" + _reason), _name, _city]] remoteExec ["A3A_fnc_customHint", teamPlayer];
};

Info_3("Town upgrade %1 in %2 removed (%3)", _id, _city, _reason);
true;
