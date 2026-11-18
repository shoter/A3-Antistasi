/*
Maintainer: Caleb Serafin, Killerswin2
    Creates the controls for the dialog. Picture and Button are created. Data Saved to buttons.

Arguments:
    <string> string for initilizer

Return Value:
    
    NONE
Scope: Client
Environment: scheduled
Public: No

Example:
    ["onLoad"] spawn A3A_GUI_fnc_teamLeaderRTSPlacerDialog

License: APL-ND
    As of 1st July 2024 Ellis Nielsen, the owner of the code, has transfered the ownership to Calep Serafin.

*/


#include "..\..\dialogues\ids.inc"
#include "..\..\dialogues\defines.hpp"
#include "..\..\dialogues\textures.inc"
#include "..\..\script_component.hpp"
#define BOTTOM safeZoneH + safeZoneY
FIX_LINE_NUMBERS()


params[["_mode","onLoad"], ["_params",[]]];

switch (_mode) do
{
    case ("onLoad"):
    {
        _params params ["_displayOrControl", ["_config", configNull]];

        private _altText = (_displayOrControl displayCtrl IDC_PLACERHINT_ALT_TEXT);
        private _eText = (_displayOrControl displayCtrl IDC_PLACERHINT_E_TEXT);
        private _rText = (_displayOrControl displayCtrl IDC_PLACERHINT_R_TEXT);
        private _shiftText = (_displayOrControl displayCtrl IDC_PLACERHINT_SHIFT_TEXT);
        private _spaceText = (_displayOrControl displayCtrl IDC_PLACERHINT_SPACE_TEXT);
        _altText ctrlSetText format ["%1 %2", localize "STR_antistasi_teamleader_placer_alt_key", localize "str_3den_display3den_entitymenu_movesurface_text"];
        // Rotation rows (E row: Turn left, R row: Turn right). The text names the bound key; the key icon stays only
        // when there is a picture of that key, otherwise it is hidden and the text alone tells the key.
        (call A3A_fnc_turnKeyNames) params ["_leftKey", "_rightKey"];
        private _keyIcons = createHashMapFromArray [["E", A3A_Icon_key_e], ["R", A3A_Icon_key_r], ["C", A3A_Icon_key_c], ["T", A3A_Icon_key_t]];
        {
            _x params ["_icon", "_keyName"];
            private _picture = _keyIcons getOrDefault [toUpper _keyName, ""];
            _icon ctrlShow (_picture != "");
            if (_picture != "") then { _icon ctrlSetText _picture };
        } forEach [
            [_displayOrControl displayCtrl IDC_PLACERHINT_E, _leftKey],
            [_displayOrControl displayCtrl IDC_PLACERHINT_R, _rightKey]
        ];
        _eText ctrlSetText format [localize "STR_antistasi_teamleader_placer_e_key", _leftKey];
        _rText ctrlSetText format [localize "STR_antistasi_teamleader_placer_r_key", _rightKey];
        _shiftText ctrlSetText localize "STR_antistasi_teamleader_placer_shift_key";
        _spaceText ctrlSetText localize "STR_antistasi_teamleader_placer_space_key";
        uiNamespace setVariable ["A3A_placerHint_display", _displayOrControl];
    };
    case ("setContextKey"):
    {
        private _display = uiNamespace getVariable "A3A_placerHint_display";
        if (isNil "_display") exitWith {};          // maybe possible with timings?

        _params params ["_keyType", "_keyData"];

        (_display displayCtrl IDC_PLACERHINT_C) ctrlShow false;
        (_display displayCtrl IDC_PLACERHINT_T) ctrlShow false;
        private _textCtrl = (_display displayCtrl IDC_PLACERHINT_C_TEXT);

        if (_keyType == "cancel") exitWith {
            (_display displayCtrl IDC_PLACERHINT_C) ctrlShow true;
            _textCtrl ctrlSetText format [localize "STR_antistasi_teamleader_placer_c_key", _keyData];
        };
        if (_keyType == "rebuild") exitWith {
            (_display displayCtrl IDC_PLACERHINT_T) ctrlShow true;
            _textCtrl ctrlSetText format [localize "STR_antistasi_teamleader_placer_t_key", _keyData];
        };
        _textCtrl ctrlSetText "";
    };
    default
    {
        // Log error if attempting to call a mode that doesn't exist
        Error_1("setupplacerhints mode does not exist: %1", _mode);
    };
};