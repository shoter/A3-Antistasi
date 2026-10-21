/*
Maintainer: Shoter
    Shows, updates and hides the timed action progress bar at the bottom centre of the screen (A3A_ProgressBar in RscTitles).
    Only one bar exists at a time; showing it again replaces the caption and resets the fill.

Arguments:
    <STRING> Mode: "show", "update" or "hide"
    <ARRAY> Params for the mode:
        "show": [<STRING> caption]
        "update": [<SCALAR> progress 0..1, <STRING> caption, unchanged when omitted]
        "hide": []

Return Value:
    Nothing

Scope: Clients, Local Effect
Environment: Any
Public: Yes
Dependencies: BIS_fnc_rscLayer

Example:
    ["show", ["Scrapping Offroad"]] call A3A_GUI_fnc_progressBar;
    ["update", [0.5, "Scrapping Offroad (20 s)"]] call A3A_GUI_fnc_progressBar;
    ["hide"] call A3A_GUI_fnc_progressBar;

License: APL-ND
*/

#include "..\..\dialogues\ids.inc"
#include "..\..\dialogues\defines.hpp"
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

#define PROGRESSBAR_FILL_W 78

params [["_mode", "", [""]], ["_params", []]];
if (!hasInterface) exitWith {};

private _layer = "A3A_progressBar" call BIS_fnc_rscLayer;

switch (_mode) do {
    case "show": {
        _params params [["_caption", "", [""]]];
        _layer cutRsc ["A3A_ProgressBar", "PLAIN", 0, false];
        private _display = uiNamespace getVariable ["A3A_progressBarDisplay", displayNull];
        (_display displayCtrl A3A_IDC_PROGRESSBARTEXT) ctrlSetText _caption;
        private _fill = _display displayCtrl A3A_IDC_PROGRESSBARFILL;
        _fill ctrlSetPositionW 0;
        _fill ctrlCommit 0;
    };
    case "update": {
        _params params [["_progress", 0, [0]], ["_caption", nil, [""]]];
        private _display = uiNamespace getVariable ["A3A_progressBarDisplay", displayNull];
        if (isNull _display) exitWith {};
        if (!isNil "_caption") then { (_display displayCtrl A3A_IDC_PROGRESSBARTEXT) ctrlSetText _caption };
        private _fill = _display displayCtrl A3A_IDC_PROGRESSBARFILL;
        _fill ctrlSetPositionW (PROGRESSBAR_FILL_W * GRID_W * ((_progress max 0) min 1));
        _fill ctrlCommit 0;
    };
    case "hide": {
        _layer cutText ["", "PLAIN"];
        uiNamespace setVariable ["A3A_progressBarDisplay", displayNull];
    };
    default { Error_1("progressBar mode does not exist: %1", _mode) };
};
