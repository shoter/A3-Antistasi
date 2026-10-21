/*
Maintainer: Shoter
    Stores a custom squad composed in the squad composer. The commander and the sub-commanders may change both
    custom squads. The composition is cleaned by A3A_fnc_customSquadSanitize, broadcast to all clients and saved
    with the campaign. The player who made the change gets the stored version back for their open composer.

Arguments:
    <OBJECT> Player making the change, has to be command staff
    <NUMBER> Custom squad index, 0 for Custom 1 or 1 for Custom 2
    <STRING> Abbreviation shown in the high command bar, 1 to 5 letters or digits
    <ARRAY> Unit counts on top of the squad leader, [[unit key, count], ...]

Return Value:
    <BOOL> True if the squad was stored

Scope: Server
Environment: Unscheduled
Public: No
Dependencies:
    A3A_customSquads, A3A_fnc_customSquadSanitize, A3A_fnc_isCommandStaff, A3A_GUI_fnc_squadComposerDialog

Example:
    [player, 0, "ABC", [["unitRifle", 5], ["unitMG", 2]]] remoteExecCall ["A3A_fnc_customSquadSet", 2];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if !(isServer) exitWith { Error("Attempted to call server function as non-server"); false };
params [["_player", objNull, [objNull]], ["_index", -1, [0]], ["_abbr", "", [""]], ["_counts", [], [[]]]];

if !([_player] call A3A_fnc_isCommandStaff) exitWith {
    Info_1("%1 tried to change a custom squad without being command staff", name _player);
    false
};
if !(_index in [0, 1]) exitWith { false };

private _squad = [_abbr, _counts, A3A_customSquads # _index # 0] call A3A_fnc_customSquadSanitize;
A3A_customSquads set [_index, _squad];
publicVariable "A3A_customSquads";

_squad params ["_storedAbbr", "_storedCounts"];
private _size = 1;
{ _size = _size + (_x # 1) } forEach _storedCounts;
private _number = _index + 1;
Info_4("%1 set custom squad %2 to %3 soldiers, abbreviation %4", name _player, _number, _size, _storedAbbr);

["saved", [_index, _squad]] remoteExecCall ["A3A_GUI_fnc_squadComposerDialog", _player];
true
