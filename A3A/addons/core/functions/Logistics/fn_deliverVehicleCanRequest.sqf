/*
Maintainer: Shoter
    Checks whether a player may request a vehicle delivery. Does not check HR or the garage entry.
    The origin and the destination are verified when given.
    Blocker keys map to "STR_A3A_fn_logistics_deliverVehicle_blk_<key>".
    Like the air taxi, the destination may be anywhere on land: the vehicle is driven there for real
    and can be intercepted on the way.

Arguments:
    <OBJECT> Player who requests the delivery
    <STRING> Origin site marker, see A3A_fnc_deliverVehicleOrigins (optional)
    <POSITION> Destination position (optional)

Return Value:
    <ARRAY<STRING>> Blocker keys, empty when the request is allowed

Scope: Any
Environment: Any
Public: Yes
Dependencies:
    A3A_deliverVehicleMinDistance

Example:
    [player, "outpost_1", getPosATL player] call A3A_fnc_deliverVehicleCanRequest;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_player", objNull, [objNull]], ["_origin", "", [""]], ["_destPos", nil, [[]]]];
private _blockers = [];

if !(isNil { _player getVariable "A3A_deliverVehicle" }) then { _blockers pushBack "active" };
if (_player != _player getVariable ["owner", _player]) then { _blockers pushBack "no_control" };
if (!isNil "A3A_FFPun_Jailed" && { (getPlayerUID _player) in A3A_FFPun_Jailed }) then { _blockers pushBack "no_ff" };

if (_origin != "") then {
    if !(_origin in ([] call A3A_fnc_deliverVehicleOrigins)) exitWith { _blockers pushBack "bad_origin" };
    if ([markerPos _origin] call A3A_fnc_enemyNearCheck) then { _blockers pushBack "origin_attack" };
};

if (!isNil "_destPos") then {
    if (count _destPos < 2 || { _destPos # 0 < 0 } || { _destPos # 1 < 0 } || { _destPos # 0 > worldSize } || { _destPos # 1 > worldSize }) exitWith {
        _blockers pushBack "off_map";
    };
    if (surfaceIsWater _destPos) then { _blockers pushBack "water" };
    if (_origin != "" && { _destPos distance2D markerPos _origin < A3A_deliverVehicleMinDistance }) then { _blockers pushBack "too_close" };
    if (!(_player call A3A_fnc_isMember || _player == theBoss) && { !([_destPos] call A3A_fnc_playerLeashCheckPosition) }) then {
        _blockers pushBack "no_members";
    };
};

_blockers
