/*
Maintainer: Shoter
    Creates a town upgrade kit crate bound to a town, tracks it in A3A_townKits, makes it loadable into vehicles
    and adds the client actions through a JIP remoteExec. Does no payment checks, use A3A_fnc_townKitPurchase for player requests.

Arguments:
    <STRING> Upgrade id, key of A3A_townUpgradeHM
    <STRING> City marker name the kit is bound to
    <ARRAY> Position ATL
    <SCALAR> Direction
    <SCALAR> Price paid, refunded when the kit is returned at HQ [DEFAULT = 0]

Return Value:
    <OBJECT> The crate, objNull on failure

Scope: Server
Environment: Unscheduled
Public: No
Dependencies:
    <STRING> A3A_townUpgradeCrateClass
    <ARRAY> A3A_townKits

Example:
    ["clinic", "Kavala", getPosATL player, 0, 2500] call A3A_fnc_townKitCreate;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if !(isServer) exitWith { Error("Attempted to call server function as non-server"); objNull };
params [["_id", "", [""]], ["_city", "", [""]], ["_pos", [], [[]]], ["_dir", 0, [0]], ["_paid", 0, [0]]];

if !(_id in A3A_townUpgradeHM) exitWith { Error_1("Unknown town upgrade %1", _id); objNull };
if (A3A_townUpgradeCrateClass == "") exitWith { Error("No town upgrade crate class available"); objNull };

private _crate = createVehicle [A3A_townUpgradeCrateClass, [0,0,0], [], 0, "CAN_COLLIDE"];
_crate setDir _dir;
_crate setPosATL _pos;
_crate setVectorUp surfaceNormal _pos;
clearWeaponCargoGlobal _crate;
clearMagazineCargoGlobal _crate;
clearItemCargoGlobal _crate;
clearBackpackCargoGlobal _crate;

_crate setVariable ["A3A_townKit", [_id, _city, _paid], true];
private _jipKey = "A3A_townKitAct_" + ((str _crate splitString ":") joinString "");
_crate setVariable ["A3A_townKitJip", _jipKey];
A3A_townKits pushBack _crate;

// Deleted by Zeus or cleanup: keep the list and the JIP entry consistent
_crate addEventHandler ["Deleted", { [_this # 0, false] call A3A_fnc_townKitRemove }];

[_crate] call A3A_Logistics_fnc_addLoadAction;          // does its own JIP
[_crate] remoteExec ["A3A_fnc_townKitAddActions", 0, _jipKey];

Info_3("Town kit %1 for %2 created at %3", _id, _city, _pos);
_crate;
