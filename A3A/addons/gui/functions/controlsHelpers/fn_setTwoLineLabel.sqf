/*
Maintainer: Shoter
Description:
    Sets a shortcut button label as two lines of upper-case structured text in one colour.
    The label is split at the space that gives the most even lines; a single word stays on one line.
    A shortcut button neither breaks a label reliably nor centres it vertically, so the button's TextPos top
    has to be set for two lines, see A3A_AdminShortcutButton.
    The colour fades like A3A_COLOR_BUTTON_TEXT_DISABLED while the control is disabled, so set the label
    again after enabling or disabling it.

Arguments:
0. <Control> shortcut button
1. <String> stringtable key of the label
2. <String> text colour as RRGGBB, e.g. "FFD933" for A3A_COLOR_BUTTON_TEXT_YELLOW (default: "FFFFFF")

Return Value:
<Bool> if successful

Scope: Clients, Local Arguments, Local Effect
Environment: Any
Public: No
Dependencies:

Example:
    [_display displayCtrl A3A_IDC_TAKECMD, "STR_antistasi_dialogs_main_admin_take_command_button", "FFD933"] call A3A_GUI_fnc_setTwoLineLabel;

License: APL-ND
*/
#include "..\..\script_component.hpp"

if (!params [
    ["_ctrl", controlNull, [controlNull]],
    ["_stringName", "", [""]],
    ["_rgb", "FFFFFF", [""]]
]) exitWith {false};

private _words = (toUpper localize _stringName) splitString " ";
private _label = _words joinString " ";
if (count _words > 1) then {
    private _split = 1;
    private _longest = 1e9;
    for "_i" from 1 to (count _words - 1) do {
        private _len = (count ((_words select [0, _i]) joinString " ")) max (count ((_words select [_i, count _words]) joinString " "));
        if (_len < _longest) then { _split = _i; _longest = _len };
    };
    _label = ((_words select [0, _split]) joinString " ") + "<br/>" + ((_words select [_split, count _words]) joinString " ");
};

// #AARRGGBB, the alpha of A3A_COLOR_BUTTON_TEXT_DISABLED is 0.25
private _alpha = ["40", "FF"] select (ctrlEnabled _ctrl);
_ctrl ctrlSetStructuredText parseText format ["<t color='#%1%2'>%3</t>", _alpha, _rgb, _label];
true
