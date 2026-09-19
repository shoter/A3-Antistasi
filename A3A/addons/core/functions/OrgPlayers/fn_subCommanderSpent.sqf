/*
Maintainer: Shoter
    Tells the commander that a sub-commander spent faction resources: who, on what and how much.
    Purchases of the commander and of players who are not sub-commanders are ignored.

Arguments:
    <OBJECT> Player who made the purchase
    <STRING> What was bought, already readable (squad name, vehicle or item display name)
    <NUMBER> Faction money spent (default 0)
    <NUMBER> HR spent (default 0)

Return Value:
    <nil>

Scope: Server
Environment: Any
Public: No
Dependencies:
    A3A_fnc_isSubCommander, A3A_fnc_subCommanderNotify

Example:
    [player, groupID _group, _cost, _costHR] remoteExecCall ["A3A_fnc_subCommanderSpent", 2];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if !(isServer) exitWith { Error("Attempted to call server function as non-server") };
params [["_player", objNull, [objNull]], ["_item", "", [""]], ["_money", 0, [0]], ["_hr", 0, [0]]];

if (isNull _player || {_player == theBoss}) exitWith {};
if !([_player] call A3A_fnc_isSubCommander) exitWith {};

Info_4("Sub-commander %1 spent %3 faction money and %4 HR on %2", name _player, _item, _money, _hr);
if (isNull theBoss) exitWith {};
["spent", [name _player, _item, _money, _hr]] remoteExecCall ["A3A_fnc_subCommanderNotify", theBoss];
