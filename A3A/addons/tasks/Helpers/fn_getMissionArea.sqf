/*
Maintainer: Shoter
    Returns the area the faction's missions take place in: the circle the commander set with the Mission Area
    button of the Commander tab, or the HQ with the lobby mission distance when none is set.

Arguments:
    None

Return Value:
    <ARRAY> [centre position, radius in metres, <BOOL> set by the commander]

Scope: Any
Environment: Any
Public: No

Example:
    (call A3A_tasks_fnc_getMissionArea) params ["_areaPos", "_areaRad"];
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

private _area = missionNamespace getVariable ["A3A_missionArea", []];
if (_area isEqualTo []) exitWith { [markerPos "Synd_HQ", missionNamespace getVariable ["distanceMission", 4000], false] };
[_area # 0, _area # 1, true];
