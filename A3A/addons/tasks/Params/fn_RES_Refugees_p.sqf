#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

(call FUNC(getMissionArea)) params ["_areaPos", "_areaRad"];
// Valid in destroyed cities...
private _cities = citiesX inAreaArrayIndexes [_areaPos, _areaRad, _areaRad] apply { citiesX#_x }
    select { sidesX getVariable _x != teamPlayer } select { spawner getVariable _x != 0 };

if (_cities isEqualTo []) exitWith {false};
[2 - tierWar/10, [selectRandom _cities]];
