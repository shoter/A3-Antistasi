/*
Maintainer: Shoter
    Hands every high command squad of a unit over to the commander.
    Used when a sub-commander loses the role or leaves the server, the squads are not handed back later.
    Without a commander the squads wait in A3A_orphanHCGroups, A3A_fnc_theBossTransfer gives them to the next one.

Arguments:
    <OBJECT> Unit losing its squads

Return Value:
    <NUMBER> Squads handed over

Scope: Server
Environment: Any
Public: No
Dependencies:
    theBoss, A3A_orphanHCGroups

Example:
    [_unit] call A3A_fnc_subCommanderTransferSquads;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if !(isServer) exitWith { Error("Attempted to call server function as non-server"); 0 };
params [["_unit", objNull, [objNull]]];

if (isNull _unit || {_unit == theBoss}) exitWith { 0 };
private _groups = hcAllGroups _unit;
if (_groups isEqualTo []) exitWith { 0 };

hcRemoveAllGroups _unit;
if (isNull theBoss) then {
    { A3A_orphanHCGroups pushBackUnique _x } forEach _groups;
} else {
    {
        theBoss hcSetGroup [_x];
        _x setGroupOwner owner theBoss;
    } forEach _groups;
};

Info_2("Handed %1 high command squads of %2 over to the commander", count _groups, name _unit);
count _groups
