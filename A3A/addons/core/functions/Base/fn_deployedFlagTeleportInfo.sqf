/*
Maintainer: Shoter
    Works out what a teleport of the local player to the commander rally flag would be right now:
    destination, distance, enemy presence at the flag, price, travel time, squad AI coming along and the reasons
    it is not possible. Shared by the confirmation dialog on the HQ flag and by A3A_fnc_deployedFlagTeleport.

    Enemies able to fight within 50 m of the flag count as enemy presence. They never block the teleport, they make it
    cost 10-20 times the war level instead of 5-15 (30-60 at war level 3, scaled by the distance, the maximum is
    reached at half the map size), keep the full fast travel time (three times faster otherwise) and make the teleport
    scatter the squad around the flag.
    Keep the numbers in sync with the dialog texts (STR_antistasi_dialogs_deployed_flag_hot / _cold).

Arguments:
    None

Return Value:
    <ARRAY> [
        <POSITION> Destination, ATL position of the flag
        <SCALAR> Distance from the player in metres
        <BOOL> Enemies present at the flag
        <SCALAR> Cost in money
        <SCALAR> Travel time in seconds
        <SCALAR> Squad AI that would come along (on foot, within 50 m of the player, only when the player leads the group)
        <ARRAY<STRING>> Localized reasons why the teleport is not possible, empty when it is. Not affording the price is not one of them.
    ]

Scope: Clients
Environment: Any
Public: No
Dependencies:
    A3A_fnc_canFastTravel, A3A_fnc_calculateFastTravelCost, A3A_fnc_playerLeashCheckPosition, A3A_fnc_canFight

Example:
    ([] call A3A_fnc_deployedFlagTeleportInfo) params ["_destPos", "_distance", "_enemyPresent", "_cost", "_travelTime", "_squadCount", "_blockers"];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

#define ENEMY_RADIUS 50
#define SQUAD_RADIUS 50

private _flag = A3A_deployedFlag;
if (isNull _flag) exitWith { [[0,0,0], 0, false, 0, 0, 0, [localize "STR_A3A_fn_base_deployedFlagTeleport_noFlag"]] };

private _destPos = getPosATL _flag;
private _distance = player distance2D _destPos;

private _blockers = [];
if (vehicle player != player) then { _blockers pushBack (localize "STR_A3A_fn_base_deployedFlagTeleport_onFoot") };
// Generic fast travel blockers: server setting, jail, remote control, enemies around the player. Destination checks are done here instead.
{ _blockers pushBack (localize ("STR_A3A_fn_dialogs_ftradio_" + _x)) } forEach ([player, player, nil] call A3A_fnc_canFastTravel);
if (!(player call A3A_fnc_isMember || player == theBoss) && {!([_destPos] call A3A_fnc_playerLeashCheckPosition)}) then {
    _blockers pushBack (localize "STR_A3A_fn_dialogs_ftradio_no_members");
};

private _enemyPresent = ((units Occupants + units Invaders) inAreaArray [_destPos, ENEMY_RADIUS, ENEMY_RADIUS]) findIf { _x call A3A_fnc_canFight } != -1;

// Price grows with the distance and tops out at half the map size
private _fraction = (_distance / (worldSize / 2)) min 1;
(if (_enemyPresent) then { [10 * tierWar, 20 * tierWar] } else { [5, 15] }) params ["_costMin", "_costMax"];
private _cost = round (_costMin + (_costMax - _costMin) * _fraction);

// Regular fast travel time for a person on foot, three times faster when nobody is waiting at the flag
[player, [player], _destPos] call A3A_fnc_calculateFastTravelCost params ["_ftCost", "_travelTime"];
if (!_enemyPresent) then { _travelTime = (round (_travelTime / 3)) max 1 };

private _squadCount = 0;
if (player == leader group player) then {
    _squadCount = { !isPlayer _x && {alive _x} && {vehicle _x == _x} } count (units group player inAreaArray [getPosATL player, SQUAD_RADIUS, SQUAD_RADIUS]);
};

[_destPos, _distance, _enemyPresent, _cost, _travelTime, _squadCount, _blockers];
