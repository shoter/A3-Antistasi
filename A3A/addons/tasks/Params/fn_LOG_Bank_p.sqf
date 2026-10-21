#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

(call FUNC(getMissionArea)) params ["_areaPos", "_areaRad"];
private _nearCities = citiesX inAreaArrayIndexes [_areaPos, _areaRad+500, _areaRad+500] apply { citiesX # _x };
if (_nearCities isEqualTo []) exitWith {false};

private _banks = banks inAreaArray [_areaPos, _areaRad, _areaRad];
_banks = _banks select {
    private _bank = _x;
    private _distances = _nearCities apply { markerPos _x distance2d _bank };
    private _nearest = _nearCities select (_distances find selectMin _distances);
    sidesX getVariable _nearest != teamPlayer;          // only want banks in enemy cities
};
if (_banks isEqualTo []) exitWith {false};

[1, [selectRandom _banks]];
