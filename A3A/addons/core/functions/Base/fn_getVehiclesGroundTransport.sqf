/*
Maintainer: John Jordan
    Returns a weighted ground transport vehicle pool based on war level and side

Arguments:
    <SIDE> The side for which the vehicle pool should be generated (occupants or invaders)
    <INTEGER> 1-10 range, war-level based vehicle quality

Return value:
    <ARRAY> [vehType, weight, vehType2, weight2, ...]
*/
params ["_side", "_level"];

if (_side == Invaders) then {_level = _level + 1};
_level = (_level max 1 min 10) - 1;
private _faction = [A3A_faction_occ, A3A_faction_inv] select (_side == Invaders);

private _fnc_addArrayToWeights = {
    params ["_vehArray", "_baseWeight"];
    { _vehWeights append [_x, _baseWeight / count _vehArray] } forEach _vehArray;
};

private _vehWeights = [];

private _policeWeight =    [ 20, 15, 10,  6,  3,  1,  0,  0,  0,  0] select _level;
private _milCarWeight =    [ 18, 18, 18, 18, 17, 16, 14, 12, 10,  8] select _level;
private _milTruckWeight =  [ 45, 38, 32, 26, 20, 15, 10,  6,  3,  0] select _level;
private _carWeight =       [  1,  2,  3,  3,  4,  5,  6,  7,  8,  9] select _level;
private _armedCarWeight =  [  4,  5,  6,  7,  8,  9, 11, 12, 13, 15] select _level;
private _truckWeight =     [  0,  5, 10, 14, 18, 22, 25, 27, 28, 29] select _level;
private _lapcWeight =      [ 12, 12, 11, 11, 10,  9,  8,  7,  6,  5] select _level;
private _apcWeight =       [  0,  5,  9, 12, 15, 17, 18, 19, 20, 20] select _level;
private _ifvWeight =       [  0,  0,  1,  3,  5,  6,  8, 10, 12, 14] select _level;

if (_faction getOrDefault ["attributeMoreTrucks", false]) then {
    _milTruckWeight =      [100, 80, 60, 35, 15,  0,  0,  0,  0,  0] select _level;
    _truckWeight =         [ 10, 20, 30, 45, 55, 60, 55, 50, 45, 40] select _level;
    _lapcWeight =          [ 10, 15, 20, 20, 20, 20, 20, 20, 20, 20] select _level;
    _apcWeight =           [  0,  4,  8, 12, 16, 20, 20, 20, 20, 20] select _level;
    _ifvWeight =           [  0,  0,  2,  4,  6,  8, 12, 16, 20, 25] select _level;
};

if (_faction get "vehiclesLightAPCs" isEqualTo []) then { _apcWeight = _apcWeight + _lapcWeight/2; _truckWeight = _truckWeight + _lapcWeight/2; };
if (_faction get "vehiclesIFVs" isEqualTo []) then { _apcWeight = _apcWeight + _ifvWeight };
if (_faction get "vehiclesAPCs" isEqualTo []) then {
    if (_faction get "vehiclesLightAPCs" isEqualTo []) exitWith { _ifvWeight = _ifvWeight + _apcWeight };
    _lapcWeight = _lapcWeight + _apcWeight;
};

[_faction get "vehiclesPolice", _policeWeight] call _fnc_addArrayToWeights;
[_faction get "vehiclesMilitiaCars", _milCarWeight] call _fnc_addArrayToWeights;
[_faction get "vehiclesMilitiaTrucks", _milTruckWeight] call _fnc_addArrayToWeights;
[_faction get "vehiclesLightUnarmed", _carWeight] call _fnc_addArrayToWeights;
[_faction get "vehiclesLightArmedTroop", _armedCarWeight] call _fnc_addArrayToWeights;
[_faction get "vehiclesTrucks", _truckWeight] call _fnc_addArrayToWeights;
[_faction get "vehiclesLightAPCs", _lapcWeight] call _fnc_addArrayToWeights;
[_faction get "vehiclesAPCs", _apcWeight] call _fnc_addArrayToWeights;
[_faction get "vehiclesIFVs", _ifvWeight] call _fnc_addArrayToWeights;

_vehWeights;
