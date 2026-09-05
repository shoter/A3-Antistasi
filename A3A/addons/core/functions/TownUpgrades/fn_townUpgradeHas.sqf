/*
Maintainer: Shoter
    Whether a town currently has the given upgrade installed. Safe to call before the server data has arrived.

Arguments:
    <STRING> City marker name
    <STRING> Upgrade id, key of A3A_townUpgradeHM

Return Value:
    <BOOL> True when installed

Scope: Any
Environment: Any
Public: No
Dependencies:
    <HASHMAP> A3A_cityInvest

Example:
    ["Kavala", "militia"] call A3A_fnc_townUpgradeHas;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_city", "", [""]], ["_id", "", [""]]];

if (isNil "A3A_cityInvest") exitWith { false };
_id in (A3A_cityInvest getOrDefault [_city, createHashMap]);
