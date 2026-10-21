#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

(call FUNC(getMissionArea)) params ["_areaPos", "_areaRad"];
private _nearCities = citiesX inAreaArrayIndexes [_areaPos, _areaRad, _areaRad] apply { citiesX#_x }
    select { sidesX getVariable _x != teamPlayer };

private _weightedMarkers = [];
{
    private _stationPos = A3A_garrison get _x getOrDefault ["policeStation", false];
    if !(_stationPos isEqualType []) then { continue };

    private _station = nearestBuilding _stationPos;
    private _dist = markerPos _x distance2d _areaPos;
    _weightedMarkers append [[_x, _station], (_areaRad - _dist) ^ 2];
} forEach (_nearCities - destroyedSites);

if (_weightedMarkers isEqualTo []) exitWith {false};        // no suitable cities
[1, selectRandomWeighted _weightedMarkers];                    // [marker, station]
