#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

(call FUNC(getMissionArea)) params ["_areaPos", "_areaRad"];
private _airports = airportsX inAreaArrayIndexes [_areaPos, _areaRad, _areaRad] apply { airportsX#_x }
    select { sidesX getVariable _x != teamPlayer } select { spawner getVariable _x != 0 };

if (_airports isEqualTo []) exitWith {false};
[1, [selectRandom _airports]];
