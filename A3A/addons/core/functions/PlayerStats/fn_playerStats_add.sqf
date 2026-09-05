/*
Maintainer: Shoter
    Adds to the statistics of a player. Remote executed on the server by the machines that observe the events.
    Only keys that exist in the record and hold numbers are accepted, anything else is ignored.
    Weapon deltas go into the per-weapon table: [seconds, enemy soldier kills, vehicle kills, aircraft kills, shots fired].

Arguments:
    <STRING> Player UID
    <ARRAY<ARRAY>> Increments as [key, delta] pairs                                              [DEFAULT=[]]
    <ARRAY<ARRAY>> Maxima as [key, value] pairs, the key keeps the larger value                   [DEFAULT=[]]
    <ARRAY<ARRAY>> Weapon deltas as [weapon or vehicle class, [dSeconds, dSoldiers, dVehicles, dAircraft, dShots]] pairs  [DEFAULT=[]]

Return Value:
    Nothing

Scope: Server
Environment: Any
Public: No
Dependencies:
    <HASHMAP> A3A_playerStats

Example:
    [getPlayerUID player, [["kills", 1]], [["longestKill", 320]], [["arifle_MX_F", [0, 1, 0, 0, 0]]]] remoteExecCall ["A3A_fnc_playerStats_add", 2];

License: APL-ND

*/

#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

#define WEAPON_FIELDS 5

if (!isServer) exitWith { Error("Miscalled server-only function") };

params [["_uid", "", [""]], ["_increments", [], [[]]], ["_maxima", [], [[]]], ["_weapons", [], [[]]]];

if (_uid == "") exitWith {};

private _stats = [_uid] call A3A_fnc_playerStats_get;

{
    _x params [["_key", "", [""]], ["_delta", 0, [0]]];
    if (_key == "" || {!(_key in _stats)} || {!((_stats get _key) isEqualType 0)}) then { continue };
    _stats set [_key, (_stats get _key) + _delta];
} forEach _increments;

{
    _x params [["_key", "", [""]], ["_value", 0, [0]]];
    if (_key == "" || {!(_key in _stats)} || {!((_stats get _key) isEqualType 0)}) then { continue };
    _stats set [_key, (_stats get _key) max _value];
} forEach _maxima;

private _weaponTable = _stats get "weapons";
{
    _x params [["_class", "", [""]], ["_deltas", [], [[]]]];
    if (_class == "" || {_deltas isEqualTo []}) then { continue };
    private _entry = _weaponTable getOrDefault [_class, [], true];
    if !(_entry isEqualType []) then { _entry = []; _weaponTable set [_class, _entry] };
    // Records from older versions may be shorter, pad them
    while { count _entry < WEAPON_FIELDS } do { _entry pushBack 0 };
    for "_i" from 0 to (WEAPON_FIELDS - 1) do {
        private _delta = _deltas param [_i, 0, [0]];
        if (_delta != 0 && {(_entry select _i) isEqualType 0}) then { _entry set [_i, (_entry select _i) + _delta] };
    };
} forEach _weapons;
