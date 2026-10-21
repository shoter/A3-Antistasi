#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

(call FUNC(getMissionArea)) params ["_areaPos", "_areaRad"];
private _outposts = outposts inAreaArrayIndexes [_areaPos, _areaRad, _areaRad] apply { outposts#_x }
    select { sidesX getVariable _x != teamPlayer } select { spawner getVariable _x != 0 };

if (_outposts isEqualTo []) exitWith {false};
[1, [selectRandom _outposts]];
