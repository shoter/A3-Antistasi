/*
Maintainer: Shoter
    Price of a town upgrade kit for a given town. Scales with the square root of the town population,
    a 250 population town pays the base price, a 1000 population town pays double. Rounded to 50 PLN, minimum 500.

Arguments:
    <STRING> Upgrade id, key of A3A_townUpgradeHM
    <STRING> City marker name

Return Value:
    <SCALAR> Price in PLN, 0 for an unknown upgrade

Scope: Any
Environment: Any
Public: No
Dependencies:
    <HASHMAP> A3A_townUpgradeHM
    <HASHMAP> A3A_cityPop

Example:
    ["clinic", "Kavala"] call A3A_fnc_townUpgradePrice;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_id", "", [""]], ["_city", "", [""]]];

if (isNil "A3A_townUpgradeHM" or {!(_id in A3A_townUpgradeHM)}) exitWith { Error_1("Unknown town upgrade %1", _id); 0 };

private _base = (A3A_townUpgradeHM get _id) # 1;
private _pop = A3A_cityPop getOrDefault [_city, 250];
500 max (50 * round (_base * sqrt (_pop / 250) / 50));
