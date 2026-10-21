#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

(call FUNC(getMissionArea)) params ["_areaPos", "_areaRad"];
private _nearCities = citiesX inAreaArrayIndexes [_areaPos, _areaRad, _areaRad] apply { citiesX#_x };

private _weightedMarkers = [];
{
    private _supportReb = (A3A_cityData getVariable _x) select 1;
    if (_supportReb < 80) then {
        private _dist = markerPos _x distance2d _areaPos;
        private _weight = (100 - _supportReb) * ((_areaRad - _dist) ^ 2);
        _weightedMarkers append [_x, _weight];
    };
} forEach (_nearCities - destroyedSites);

if (_weightedMarkers isEqualTo []) exitWith {false};        // no suitable cities
[1, [selectRandomWeighted _weightedMarkers]];                    // just returns city marker
