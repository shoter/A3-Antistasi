/*
Maintainer: Shoter
    Creates the prop of a town upgrade, registers it in A3A_cityInvest (broadcast) and A3A_townUpgradeObjects,
    creates its map marker and adds the client actions through a JIP remoteExec.
    Does no permission or payment checks, use A3A_fnc_townUpgradeInstall for player requests.
    Destruction or deletion of the prop by anything else goes through A3A_fnc_townUpgradeRemove.

Arguments:
    <STRING> City marker name
    <STRING> Upgrade id, key of A3A_townUpgradeHM
    <ARRAY> Position (getPosWorld format)
    <ARRAY> vectorDir
    <ARRAY> vectorUp

Return Value:
    <OBJECT> The created prop, objNull on failure

Scope: Server
Environment: Unscheduled
Public: No
Dependencies:
    <HASHMAP> A3A_townUpgradeHM, A3A_cityInvest, A3A_townUpgradeObjects

Example:
    ["Kavala", "clinic", getPosWorld player, vectorDir player, vectorUp player] call A3A_fnc_townUpgradeCreate;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if !(isServer) exitWith { Error("Attempted to call server function as non-server"); objNull };
params [["_city", "", [""]], ["_id", "", [""]], ["_posWorld", [], [[]]], ["_vecDir", [0,1,0], [[]]], ["_vecUp", [0,0,1], [[]]]];

if !(_id in A3A_townUpgradeHM) exitWith { Error_1("Unknown town upgrade %1", _id); objNull };
if ([_city, _id] call A3A_fnc_townUpgradeHas) exitWith { Error_2("Town %1 already has a %2", _city, _id); objNull };
(A3A_townUpgradeHM get _id) params ["_class", "", "_markerType"];
if (_class == "") exitWith { Error_1("Town upgrade %1 has no prop class", _id); objNull };

private _prop = createVehicle [_class, [0,0,0], [], 0, "CAN_COLLIDE"];
_prop setPosWorld _posWorld;
_prop setVectorDirAndUp [_vecDir, _vecUp];
_prop setVariable ["A3A_townUpgrade", [_city, _id], true];

// Registry, published so clients can read it (Towns tab, buy tab, garrison limit, fast travel)
A3A_townUpgradeObjects set [_city + "|" + _id, _prop];
private _cityUpgrades = A3A_cityInvest getOrDefault [_city, createHashMap];
_cityUpgrades set [_id, [_posWorld, _vecDir, _vecUp]];
A3A_cityInvest set [_city, _cityUpgrades];
publicVariable "A3A_cityInvest";

// Killed by anyone or deleted by Zeus/cleanup: drop the upgrade through the single removal path.
// The registry check keeps a stale object from removing a replacement upgrade.
private _fnc_gone = {
    params ["_prop"];
    (_prop getVariable ["A3A_townUpgrade", ["", ""]]) params ["_city", "_id"];
    if (A3A_townUpgradeObjects getOrDefault [_city + "|" + _id, objNull] isEqualTo _prop) then {
        [_city, _id, "lost"] call A3A_fnc_townUpgradeRemove;
    };
};
_prop addEventHandler ["Killed", _fnc_gone];
_prop addEventHandler ["Deleted", _fnc_gone];

private _mrkName = format ["A3A_townUpg_%1_%2", _city, _id];
deleteMarker _mrkName;          // safety net for leftovers
private _mrk = createMarker [_mrkName, [_posWorld # 0, _posWorld # 1]];
_mrk setMarkerShape "ICON";
_mrk setMarkerType _markerType;
_mrk setMarkerColor colorTeamPlayer;
_mrk setMarkerSize [0.7, 0.7];
_mrk setMarkerText (localize format ["STR_A3A_fn_townUpgrades_name_%1", _id]);

[_prop] remoteExec ["A3A_fnc_townUpgradeAddActions", 0, format ["A3A_townUpgAct_%1_%2", _city, _id]];

// The garrison limit is part of the town marker text
if (_id == "militia") then { [_city] call A3A_fnc_mrkUpdate };

Info_2("Town upgrade %1 created in %2", _id, _city);
_prop;
