/*
Maintainer: Shoter
    Handles a commander request to dismantle a town upgrade prop. No refund.

Arguments:
    <OBJECT> The upgrade prop
    <OBJECT> Player requesting the removal

Return Value:
    <nil>

Scope: Server
Environment: Unscheduled
Public: No
Dependencies:

Example:
    [_prop, player] remoteExecCall ["A3A_fnc_townUpgradeDismantle", 2];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if !(isServer) exitWith { Error("Attempted to call server function as non-server") };
params [["_prop", objNull, [objNull]], ["_player", objNull, [objNull]]];

if (isNull _prop or isNull _player) exitWith {};
if (_player != theBoss) exitWith { Error_1("Dismantle requested by non-commander %1", name _player) };

(_prop getVariable ["A3A_townUpgrade", ["", ""]]) params ["_city", "_id"];
if (_id == "") exitWith {};
if !(A3A_townUpgradeObjects getOrDefault [_city + "|" + _id, objNull] isEqualTo _prop) exitWith { Info_2("Dismantle of %1 in %2 ignored, prop is not the registered one", _id, _city) };

[_city, _id, "dismantled"] call A3A_fnc_townUpgradeRemove;
Info_3("Town upgrade %1 in %2 dismantled by %3", _id, _city, name _player);
