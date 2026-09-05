/*
Maintainer: Shoter
    Sabotage loop for a town under an invader punishment attack. Spawned by invaderPunish and terminated with it.
    Every 15 s each upgrade prop is checked: an attacker within 25 m and no rebel within 60 m adds exposure,
    30 s of exposure destroys the upgrade. Deterministic, does not rely on the AI destroying buildings.

Arguments:
    <STRING> City marker name
    <ARRAY<OBJECT>> Attacking soldiers

Return Value:
    <nil>

Scope: Server
Environment: Scheduled
Public: No
Dependencies:
    <HASHMAP> A3A_cityInvest, A3A_townUpgradeObjects

Example:
    private _handle = [_mrkDest, _soldiers] spawn A3A_fnc_townUpgradeSabotage;
    terminate _handle;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if !(isServer) exitWith { Error("Attempted to call server function as non-server") };
params [["_city", "", [""]], ["_soldiers", [], [[]]]];

private _exposure = createHashMap;
while {true} do {
    sleep 15;
    private _ids = keys (A3A_cityInvest getOrDefault [_city, createHashMap]);
    if (_ids isEqualTo []) exitWith {};
    private _raiders = _soldiers select { alive _x };
    if (_raiders isEqualTo []) exitWith {};

    {
        private _id = _x;
        private _prop = A3A_townUpgradeObjects getOrDefault [_city + "|" + _id, objNull];
        if (isNull _prop) then { continue };
        private _pos = getPosATL _prop;

        if ((_raiders inAreaArray [_pos, 25, 25]) isEqualTo []) then { _exposure set [_id, 0]; continue };
        private _defenders = (allUnits inAreaArray [_pos, 60, 60]) select { alive _x and side group _x == teamPlayer };
        if (_defenders isNotEqualTo []) then { continue };

        private _seconds = (_exposure getOrDefault [_id, 0]) + 15;
        _exposure set [_id, _seconds];
        if (_seconds >= 30) then {
            Info_2("Town upgrade %1 in %2 sabotaged by raiders", _id, _city);
            [_city, _id, "sabotage"] call A3A_fnc_townUpgradeRemove;
        };
    } forEach _ids;
};
