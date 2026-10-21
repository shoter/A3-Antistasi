/*
Maintainer: Shoter
    Draws the mission area on the commander map, which hides normal map markers.
    The current area is outlined whenever the commander set one. While the Mission Area view is open the
    outline is shown for the HQ default too, and the area being picked is drawn filled with its radius.

Arguments:
    <CONTROL> Commander map

Return Value:
    None

Scope: Clients
Environment: Unscheduled
Public: No
Dependencies:
    Main Dialog must be open, A3A_tasks_fnc_getMissionArea

Example:
    _commanderMap ctrlAddEventHandler ["Draw","_this call A3A_GUI_fnc_missionAreaEH"];
*/

#include "..\..\dialogues\ids.inc"
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

#define CURRENT_COLOR [0, 0.5, 0, 1]
#define NEW_COLOR [0.9, 0.6, 0, 1]
#define NEW_FILL "#(rgb,8,8,3)color(0.9,0.6,0,0.15)"
#define DOT_ICON "\A3\ui_f\data\map\markers\military\dot_CA.paa"

params ["_map"];

private _display = findDisplay A3A_IDD_MAINDIALOG;
private _missionAreaControlsGroup = _display displayCtrl A3A_IDC_MISSIONAREACONTROLSGROUP;
private _editing = ctrlShown _missionAreaControlsGroup;

(call A3A_tasks_fnc_getMissionArea) params ["_areaPos", "_areaRad", "_areaSet"];
if (_areaSet or _editing) then {
    _map drawEllipse [_areaPos, _areaRad, _areaRad, 0, CURRENT_COLOR, ""];
    _map drawIcon [DOT_ICON, CURRENT_COLOR, _areaPos, 16, 16, 0, localize "STR_antistasi_dialogs_main_mission_area_current_label", 2];
};

if (!_editing) exitWith {};
private _newPos = _missionAreaControlsGroup getVariable ["areaPos", []];
if (_newPos isEqualTo []) exitWith {};
private _newRad = _missionAreaControlsGroup getVariable ["areaRadius", _areaRad];
_map drawEllipse [_newPos, _newRad, _newRad, 0, NEW_COLOR, NEW_FILL];
_map drawEllipse [_newPos, _newRad, _newRad, 0, NEW_COLOR, ""];
_map drawIcon [DOT_ICON, NEW_COLOR, _newPos, 16, 16, 0, localize "STR_antistasi_dialogs_main_mission_area_new_label", 2];
