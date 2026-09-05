/*
Maintainer: Shoter
    Sets how mission rewards are split: the faction tax paid into the war chest and the commander's personal cut.
    Whatever is left goes to the players who took part, see A3A_tasks_fnc_rewardPlayers.
    Only the current commander may change the split, and a guest commander may not while membership is enabled.
    Values are whole percentages, clamped to 0-50 for the tax and 0-20 for the cut, broadcast to all clients and saved.

Arguments:
    <OBJECT> Player requesting the change
    <NUMBER> Faction tax percentage
    <NUMBER> Commander cut percentage

Return Value:
    <BOOL> True if the split was changed

Scope: Server
Environment: Unscheduled
Public: No
Dependencies:
    A3A_fnc_isMember

Example:
    [player, 10, 20] remoteExecCall ["A3A_fnc_setRewardShares", 2];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if !(isServer) exitWith { Error("Attempted to call server function as non-server"); false };
params [["_player", objNull, [objNull]], ["_taxPercent", 0, [0]], ["_cutPercent", 20, [0]]];

if (isNull _player) exitWith { false };
if (_player != theBoss) exitWith {
    Info_1("%1 tried to change the reward split without being commander", name _player);
    false
};
if !([_player] call A3A_fnc_isMember) exitWith {
    Info_1("Guest commander %1 tried to change the reward split", name _player);
    false
};

_taxPercent = 0 max round _taxPercent min 50;
_cutPercent = 0 max round _cutPercent min 20;
if (_taxPercent == A3A_rewardTaxPercent && _cutPercent == A3A_rewardCommanderPercent) exitWith { false };

A3A_rewardTaxPercent = _taxPercent;
publicVariable "A3A_rewardTaxPercent";
A3A_rewardCommanderPercent = _cutPercent;
publicVariable "A3A_rewardCommanderPercent";
Info_3("Commander %1 set the reward split to faction tax %2 and commander cut %3", name _player, _taxPercent, _cutPercent);
true
