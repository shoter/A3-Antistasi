#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

(call FUNC(getMissionArea)) params ["_areaPos", "_areaRad"];
private _camps = controlsX inAreaArrayIndexes [_areaPos, _areaRad, _areaRad] apply { controlsX#_x }
    select {!isOnRoad markerPos _x} select { sidesX getVariable _x != teamPlayer };

if (_camps isEqualTo []) exitWith {false};
[1, [selectRandom _camps]];
