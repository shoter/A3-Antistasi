#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

(call FUNC(getMissionArea)) params ["_areaPos", "_areaRad"];
// Allow spawned for some reason? hmm
private _seaports = seaports inAreaArrayIndexes [_areaPos, _areaRad, _areaRad] apply { seaports # _x }
	select { sidesX getVariable _x != teamPlayer };

if (_seaports isEqualTo []) exitWith {false};
[1, [selectRandom _seaports]];
