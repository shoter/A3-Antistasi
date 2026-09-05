/*
Maintainer: Shoter
    Spends an ammo truck's ammo points on the armed vehicles of a rebel garrison, statics first.
    Uses the same price per round and the same magazine handling as the player rearm dialog
    (gui/functions/RRR/fn_serviceVehicle.sqf). Spawned vehicles are rearmed live through
    A3A_GUI_fnc_serviceVehicleGlobal on their owner; despawned ones get their stored garage state rewritten,
    which fn_spawnGarrisonVehicles restores on the next spawn.

Arguments:
    <STRING> Marker of the garrison
    <OBJECT> Ammo truck, its A3A_rearmCargo points are spent

Return Value:
    <ARRAY> [<NUMBER> ammo points spent, <NUMBER> vehicles that received ammunition]

Scope: Server
Environment: Any
Public: No
Dependencies:
    A3A_garrison, spawner, HR_GRG_fnc_getDefaultMags, A3A_GUI_fnc_calculateItemPrice, A3A_fnc_garrisonServer_findVehicle

Example:
    [_marker, _truck] call A3A_fnc_garrisonResupplyApply;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_marker", "", [""]], ["_truck", objNull, [objNull]]];

private _garrison = A3A_garrison getOrDefault [_marker, createHashMap];
private _spawned = spawner getVariable [_marker, 2] != 2;
private _blacklistMags = ["FakeWeapon", "FakeMagazine"];

private _points = _truck getVariable ["A3A_rearmCargo", 0];
private _pointsAtStart = _points;
private _serviced = 0;

// Statics first, they are what the garrison fights with
private _entries = _garrison getOrDefault ["vehicles", []];
private _order = (_entries select { (_x # 0) isKindOf "StaticWeapon" }) + (_entries select { !((_x # 0) isKindOf "StaticWeapon") });

{
    if (_points <= 0) exitWith {};
    private _entry = _x;
    private _class = _entry # 0;

    private _defaultMags = ([_class] call HR_GRG_fnc_getDefaultMags) select { !((_x # 0) in _blacklistMags) };
    if (_defaultMags isEqualTo []) then { continue };

    // Default loadout combined per magazine type and turret: key -> [mag, turret, current, max, pricePerRound]
    private _magsHM = createHashMap;
    {
        _x params ["_mag", "_turret", "_rounds"];
        private _key = toLower _mag + str _turret;
        private _val = _magsHM getOrDefault [_key, [_mag, _turret, 0, 0, -1], true];
        _val set [3, (_val # 3) + _rounds];
        if (_val # 4 < 0) then { _val set [4, ([_mag, "mag"] call A3A_GUI_fnc_calculateItemPrice) * A3A_REARM_PRICE_MUL] };
    } forEach _defaultMags;

    // Current rounds from the live object, or from the stored state when the site is despawned
    private _veh = if (_spawned) then { [_marker, _entry] call A3A_fnc_garrisonServer_findVehicle } else { objNull };
    private _state = if (isNil { _entry # 2 }) then { [] } else { _entry # 2 };
    if (!isNull _veh) then {
        {
            _x params ["_mag", "_turret", "_rounds"];
            private _key = toLower _mag + str _turret;
            if (_key in _magsHM) then { (_magsHM get _key) set [2, ((_magsHM get _key) # 2) + _rounds] };
        } forEach magazinesAllTurrets _veh;
    } else {
        if (_spawned) then { continue };            // spawned but gone, nothing to fill
        private _ammoData = _state param [2, []];
        call {
            // Slots are fetched by key: hashmap get hands out the stored array itself, so set writes through
            if (_ammoData isEqualType 0) exitWith { { private _slot = _magsHM get _x; _slot set [2, (_slot # 3) * _ammoData] } forEach keys _magsHM };
            if (_ammoData isEqualTo []) exitWith { { private _slot = _magsHM get _x; _slot set [2, _slot # 3] } forEach keys _magsHM };        // never touched, full
            {
                _x params ["_isPylon", "_data"];
                if (_isPylon) then { continue };
                _data params ["_mag", "_turret", "_rounds"];
                private _key = toLower _mag + str _turret;
                if (_key in _magsHM) then { (_magsHM get _key) set [2, ((_magsHM get _key) # 2) + _rounds] };
            } forEach _ammoData;
        };
    };

    // Buy rounds for every slot with a deficit until the points run out
    private _bought = false;
    {
        private _slot = _magsHM get _x;
        _slot params ["_mag", "_turret", "_current", "_max", "_price"];
        private _deficit = _max - _current;
        if (_deficit <= 0) then { continue };
        private _affordable = if (_price <= 0) then { _deficit } else { floor (_points / _price) };
        private _buy = _deficit min _affordable;
        if (_buy <= 0) then { continue };

        _points = _points - _buy * _price;
        _slot set [2, _current + _buy];
        _bought = true;

        if (!isNull _veh) then {
            // Same magazine split as fn_serviceVehicle: full boxes plus one partial, applied where the turret is local
            private _targetRounds = _current + _buy;
            private _roundsPerMag = getNumber (configFile >> "CfgMagazines" >> _mag >> "count") max 1;
            private _fullBoxes = floor (_targetRounds / _roundsPerMag);
            private _partialMagSize = _targetRounds % _roundsPerMag;
            if (_partialMagSize isEqualTo 0) then {
                _fullBoxes = _fullBoxes - 1;
                _partialMagSize = _roundsPerMag;
            };
            [_veh, "rearm", [_mag, _turret, _fullBoxes, _partialMagSize]] remoteExecCall ["A3A_GUI_fnc_serviceVehicleGlobal", 0];
        };
    } forEach keys _magsHM;
    if (!_bought) then { continue };
    _serviced = _serviced + 1;

    // Despawned: rewrite the stored ammo data, in the same shapes HR_GRG_fnc_getAmmoData produces
    if (isNull _veh) then {
        private _slots = values _magsHM;
        private _allFull = _slots findIf { (_x # 2) < (_x # 3) } == -1;
        private _magNames = _defaultMags apply { toLower (_x # 0) };
        private _singleMagType = count (_magNames arrayIntersect _magNames) <= 1;       // intersect with itself = unique names
        private _newAmmoData = call {
            if (_allFull) exitWith { 1 };
            if (_singleMagType) exitWith {
                private _total = 0; private _max = 0;
                { _total = _total + (_x # 2); _max = _max + (_x # 3) } forEach _slots;
                _total / (_max max 1)
            };
            // Mixed magazines: explicit list, full magazines then one partial per slot, pylons kept as they were
            private _remaining = createHashMap;
            { _remaining set [_x, (_magsHM get _x) # 2] } forEach keys _magsHM;
            private _list = [];
            {
                _x params ["_mag", "_turret", "_rounds"];
                private _key = toLower _mag + str _turret;
                private _left = _remaining get _key;
                if (_left <= 0) then { continue };
                private _count = _left min _rounds;
                _list pushBack [false, [_mag, _turret, _count]];
                _remaining set [_key, _left - _count];
            } forEach _defaultMags;
            private _oldAmmoData = _state param [2, []];
            if (_oldAmmoData isEqualType []) then { _list append (_oldAmmoData select { _x # 0 }) };
            _list
        };
        _entry set [2, [_state param [0, 1], _state param [1, 0], _newAmmoData, _state param [3, []]]];
    };
} forEach _order;

_truck setVariable ["A3A_rearmCargo", _points, true];
[_pointsAtStart - _points, _serviced]
