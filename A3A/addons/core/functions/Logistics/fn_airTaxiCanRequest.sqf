/*
Maintainer: Shoter
    Checks whether a player may request an air taxi. Does not check money, HR or the garage.
    If a destination position is given, the destination is verified too.
    Blocker keys map to "STR_A3A_fn_logistics_airTaxi_blk_<key>".
    Deliberately ignores limitedFT and who owns the ground at the destination: the taxi is the
    physical, interceptable alternative to fast travel, so any position on land is allowed.

Arguments:
    <OBJECT> Player who requests the taxi
    <POSITION> Destination position (optional)

Return Value:
    <ARRAY<STRING>> Blocker keys, empty when the request is allowed

Scope: Any
Environment: Any
Public: Yes
Dependencies:

Example:
    [player, markerPos "outpost_1"] call A3A_fnc_airTaxiCanRequest;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_player", objNull, [objNull]], ["_destPos", nil, [[]]]];
private _blockers = [];

if !(isNil { _player getVariable "A3A_airTaxi" }) then { _blockers pushBack "active" };
if (_player != _player getVariable ["owner", _player]) then { _blockers pushBack "no_control" };
if (!isNil "A3A_FFPun_Jailed" && { (getPlayerUID _player) in A3A_FFPun_Jailed }) then { _blockers pushBack "no_ff" };
if (vehicle _player != _player) then { _blockers pushBack "in_vehicle" };
if (captive _player) then { _blockers pushBack "undercover" };
if ([getPosATL _player] call A3A_fnc_enemyNearCheck) then { _blockers pushBack "no_enemy1" };

if (!isNil "_destPos") then {
    if (count _destPos < 2 || { _destPos # 0 < 0 } || { _destPos # 1 < 0 } || { _destPos # 0 > worldSize } || { _destPos # 1 > worldSize }) exitWith {
        _blockers pushBack "off_map";
    };
    if (surfaceIsWater _destPos) then { _blockers pushBack "water" };
    if (_destPos distance2D _player < A3A_airTaxiMinDistance) then { _blockers pushBack "too_close" };
    if (!(_player call A3A_fnc_isMember || _player == theBoss) && { !([_destPos] call A3A_fnc_playerLeashCheckPosition) }) then {
        _blockers pushBack "no_members";
    };
};

_blockers
