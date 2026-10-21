#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

(call FUNC(getMissionArea)) params ["_areaPos", "_areaRad"];
private _potentials = outposts + resourcesX + (controlsX select {isOnRoad markerPos _x});
private _valid = _potentials inAreaArrayIndexes [_areaPos, _areaRad, _areaRad] apply { _potentials#_x }
    select { sidesX getVariable _x != teamPlayer };

if (_valid isEqualTo []) exitWith {false};
[1, [selectRandom _valid]];
