/*
Maintainer: Shoter
    Handles a commander request to return a town upgrade kit at HQ. The crate is removed and the price paid is refunded.

Arguments:
    <OBJECT> The kit crate
    <OBJECT> Player requesting the return

Return Value:
    <nil>

Scope: Server
Environment: Unscheduled
Public: No
Dependencies: A3A_fnc_resourcesFIA, A3A_fnc_townKitRemove

Example:
    [_crate, player] remoteExecCall ["A3A_fnc_townKitReturn", 2];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if !(isServer) exitWith { Error("Attempted to call server function as non-server") };
params [["_crate", objNull, [objNull]], ["_player", objNull, [objNull]]];

if (isNull _crate or isNull _player) exitWith {};
private _titleStr = localize "STR_A3A_fn_townUpgrades_title";
if (_player != theBoss) exitWith { Error_1("Kit return requested by non-commander %1", name _player) };
if !(_crate in A3A_townKits) exitWith { [_titleStr, localize "STR_A3A_fn_townUpgrades_notAKit"] remoteExec ["A3A_fnc_customHint", _player] };
if !(_crate inArea "Synd_HQ") exitWith { [_titleStr, localize "STR_A3A_fn_townUpgrades_returnNotAtHQ"] remoteExec ["A3A_fnc_customHint", _player] };

(_crate getVariable ["A3A_townKit", ["", "", 0]]) params ["_id", "_city", "_paid"];
[_crate] call A3A_fnc_townKitRemove;
if (_paid > 0) then { [0, _paid] call A3A_fnc_resourcesFIA };

private _name = localize format ["STR_A3A_fn_townUpgrades_name_%1", _id];
[_titleStr, format [localize "STR_A3A_fn_townUpgrades_returned", _name, _city, _paid]] remoteExec ["A3A_fnc_customHint", _player];
Info_4("Town kit %1 for %2 returned by %3, refunded %4", _id, _city, name _player, _paid);
