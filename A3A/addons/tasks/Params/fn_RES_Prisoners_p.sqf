#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

(call FUNC(getMissionArea)) params ["_areaPos", "_areaRad"];
private _potentials = outposts + airportsX;
private _valid = _potentials inAreaArrayIndexes [_areaPos, _areaRad, _areaRad] apply { _potentials#_x }
    select { sidesX getVariable _x != teamPlayer } select { spawner getVariable _x != 0 };

if (_valid isEqualTo []) exitWith {false};
[tierWar/10, [selectRandom _valid]];
