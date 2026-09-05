/*
Maintainer: Shoter
    Handles the initialization of the Junkyard dialog: builds one card per wrecked vehicle in A3A_junkyardStock
    with preview, seats, weapons, price and a buy button. Card layout follows the Buy Vehicle dialog.

Arguments:
    <STRING> Mode, only possible value for this dialog is "onLoad"
    <ARRAY<ANY>> Array of params for the mode when applicable.

Return Value:
    Nothing

Scope: Clients, Local Arguments, Local Effect
Environment: Scheduled for onLoad mode
Public: No
Dependencies:
    A3A_junkyardStock, A3A_junkyardNextRefresh, A3A_GUI_fnc_getVehicleCrewCount, A3A_fnc_getVehicleWeapons, A3A_fnc_junkyardBuy

Example:
    ["onLoad"] spawn A3A_GUI_fnc_junkyardDialog;

License: APL-ND
*/

#include "..\..\dialogues\ids.inc"
#include "..\..\dialogues\defines.hpp"
#include "..\..\dialogues\textures.inc"
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_mode", "onLoad"], ["_params", []]];

if (_mode != "onLoad") exitWith { Error_1("JunkyardDialog mode does not exist: %1", _mode) };

private _display = findDisplay A3A_IDD_JUNKYARDDIALOG;
player setCaptive false;

// Faction funds option is for the commander only
private _isBoss = player == theBoss;
{ (_display displayCtrl _x) ctrlShow _isBoss } forEach [A3A_IDC_JUNKYARDFACTIONFUNDS, A3A_IDC_JUNKYARDFACTIONFUNDSTEXT];

// Debug refresh button for admins (server re-checks admin status)
(_display displayCtrl A3A_IDC_JUNKYARDREFRESHBUTTON) ctrlShow (call A3A_fnc_isLocalAdmin);

// Stock summary and next delivery
private _remaining = (A3A_junkyardNextRefresh - serverTime) max 0;
private _prettyTime = [_remaining, 1, 1, false, 2, false, true] call A3A_fnc_timeSpan_format;
(_display displayCtrl A3A_IDC_JUNKYARDINFOTEXT) ctrlSetText format [localize "STR_antistasi_dialogs_junkyard_info", count A3A_junkyardStock, _prettyTime];

private _objPreview = _display displayCtrl A3A_IDC_JUNKYARDOBJECTRENDER;
_objPreview ctrlShow false;

private _vehiclesControlsGroup = _display displayCtrl A3A_IDC_JUNKYARDVEHICLESGROUP;

if (A3A_junkyardStock isEqualTo []) exitWith {
    private _emptyText = _display ctrlCreate ["A3A_InfoTextLeft", -1, _vehiclesControlsGroup];
    _emptyText ctrlSetPosition [7 * GRID_W, 5 * GRID_H, 140 * GRID_W, 4 * GRID_H];
    _emptyText ctrlSetText (localize "STR_antistasi_dialogs_junkyard_empty");
    _emptyText ctrlCommit 0;
};

// Card geometry in grid units
#define CARD_W 44
#define CARD_H 46
#define CARD_GAP_X 7
#define CARD_GAP_Y 3
#define PICTURE_H 22

private _added = 0;
{
    _x params ["_className", "_price"];
    private _configClass = configFile >> "CfgVehicles" >> _className;
    if (!isClass _configClass) then { continue };

    ([_className] call A3A_GUI_fnc_getVehicleCrewCount) params ["_driver", "_coPilot", "_commander", "_gunners", "_passengers", "_passengersFFV"];
    private _displayName = getText (_configClass >> "displayName");
    private _editorPreview = getText (_configClass >> "editorPreview");
    private _model = getText (_configClass >> "model");
    private _hasVehiclePreview = fileExists _editorPreview;

    private _weapons = [_className] call A3A_fnc_getVehicleWeapons;
    private _weaponsText = if (_weapons isEqualTo []) then {
        localize "STR_antistasi_dialogs_junkyard_unarmed"
    } else {
        format [localize "STR_antistasi_dialogs_junkyard_weapons", _weapons joinString ", "]
    };
    private _seatsText = format [localize "STR_antistasi_dialogs_junkyard_seats", _driver + _coPilot, _gunners + _commander, _passengers];

    private _itemXpos = CARD_GAP_X * GRID_W + ((CARD_GAP_X + CARD_W) * GRID_W) * (_added mod 3);
    private _itemYpos = CARD_GAP_Y * GRID_H + (floor (_added / 3)) * ((CARD_H + CARD_GAP_Y) * GRID_H);

    private _itemControlsGroup = _display ctrlCreate ["A3A_ControlsGroupNoScrollbars", -1, _vehiclesControlsGroup];
    _itemControlsGroup ctrlSetPosition [_itemXpos, _itemYpos, CARD_W * GRID_W, CARD_H * GRID_H];
    _itemControlsGroup ctrlSetFade 1;
    _itemControlsGroup ctrlCommit 0;

    private _previewPicture = _display ctrlCreate ["A3A_Picture", A3A_IDC_JUNKYARDVEHICLEPREVIEW, _itemControlsGroup];
    _previewPicture ctrlSetPosition [0, 0, CARD_W * GRID_W, PICTURE_H * GRID_H];
    _previewPicture ctrlSetText _editorPreview;
    _previewPicture ctrlCommit 0;

    private _priceText = _display ctrlCreate ["A3A_InfoTextRight", -1, _itemControlsGroup];
    _priceText ctrlSetPosition [23 * GRID_W, (PICTURE_H - 4) * GRID_H, 20 * GRID_W, 3 * GRID_H];
    _priceText ctrlSetText format ["%1 €", _price];
    _priceText ctrlCommit 0;

    private _infoText = _display ctrlCreate ["A3A_StructuredText", -1, _itemControlsGroup];
    _infoText ctrlSetPosition [1 * GRID_W, (PICTURE_H + 0.5) * GRID_H, (CARD_W - 2) * GRID_W, 12 * GRID_H];
    _infoText ctrlSetStructuredText parseText format ["<t size='0.7'>%1<br/>%2</t>", _seatsText, _weaponsText];
    _infoText ctrlCommit 0;

    private _button = _display ctrlCreate ["A3A_ShortcutButton", -1, _itemControlsGroup];
    _button ctrlSetPosition [0, (CARD_H - 10) * GRID_H, CARD_W * GRID_W, 10 * GRID_H];
    _button ctrlSetText _displayName;
    _button ctrlSetTooltip format [localize "STR_antistasi_dialogs_junkyard_button_tooltip", _displayName, _price, round (A3A_junkyardJunkDuration / 3600)];
    _button setVariable ["className", _className];
    _button setVariable ["model", _model];
    _button ctrlAddEventHandler ["ButtonClick", {
        params ["_control"];
        private _display = findDisplay A3A_IDD_JUNKYARDDIALOG;
        private _useFactionFunds = player == theBoss && { cbChecked (_display displayCtrl A3A_IDC_JUNKYARDFACTIONFUNDS) };
        private _className = _control getVariable "className";
        closeDialog 2;
        [_className, _useFactionFunds] spawn A3A_fnc_junkyardBuy;
    }];
    _button ctrlCommit 0;

    // 3D render fallback when there is no editor preview picture, same as the Buy Vehicle dialog
    if (!_hasVehiclePreview) then {
        _button ctrlAddEventHandler ["MouseEnter", {
            params ["_control"];
            private _UIScaleAdjustment = (0.55 / getResolution#5);
            private _model = _control getVariable "model";
            private _className = _control getVariable "className";
            private _display = findDisplay A3A_IDD_JUNKYARDDIALOG;
            private _objPreview = _display displayCtrl A3A_IDC_JUNKYARDOBJECTRENDER;
            _objPreview ctrlSetModel _model;
            private _boundingDiameter = [_className] call FUNC(sizeOf);
            _objPreview ctrlSetModelScale (2.25 / _boundingDiameter * _UIScaleAdjustment);
            _objPreview ctrlSetModelDirAndUp [[-0.6283, 0.3601, 0.6896], [-0.0125, -0.5015, 0.8651]];

            private _editorPreviewPicture = ctrlParentControlsGroup _control controlsGroupCtrl A3A_IDC_JUNKYARDVEHICLEPREVIEW;
            private _mouseAbsolutePos = getMousePosition;
            private _mouseRelativePos = ctrlMousePosition _editorPreviewPicture;
            _mouseAbsolutePos vectorDiff _mouseRelativePos params ["_objPreview_x", "_objPreview_y"];

            private _yAdjustment = 0.25 * _UIScaleAdjustment;
            _objPreview ctrlSetPosition [_objPreview_x + 0.5 * (22 * pixelW * pixelGridNoUIScale), 4, _objPreview_y - 0.5 * (12.5 * pixelW * pixelGridNoUIScale) + _yAdjustment];
            _editorPreviewPicture ctrlShow false;
            _editorPreviewPicture ctrlCommit 1;
            _objPreview ctrlShow true;
            _objPreview ctrlEnable false;
        }];
        _button ctrlAddEventHandler ["MouseExit", {
            params ["_control"];
            private _display = findDisplay A3A_IDD_JUNKYARDDIALOG;
            private _objPreview = _display displayCtrl A3A_IDC_JUNKYARDOBJECTRENDER;
            private _editorPreviewPicture = ctrlParentControlsGroup _control controlsGroupCtrl A3A_IDC_JUNKYARDVEHICLEPREVIEW;
            _editorPreviewPicture ctrlShow true;
            _editorPreviewPicture ctrlCommit 1;
            _objPreview ctrlShow false;
        }];
    };

    // Crew icons with counts, bottom-left of the picture
    private _hasGunners = [0, 1] select (_gunners > 0);
    private _hasPassengers = [0, 1] select (_passengers > 0);
    private _numberOfCrewTypes = ([0, 1] select (_driver > 0 || _coPilot > 0)) + _commander + _hasGunners + _hasPassengers;
    private _crewCountHeight = _numberOfCrewTypes * 4.5 * GRID_H;

    private _crewControlsGroup = _display ctrlCreate ["A3A_ControlsGroupNoScrollbars", -1, _itemControlsGroup];
    _crewControlsGroup ctrlSetPosition [1 * GRID_W, (PICTURE_H - 1) * GRID_H - _crewCountHeight, 20 * GRID_W, _crewCountHeight];
    _crewControlsGroup ctrlCommit 0;

    private _fnc_crewIcon = {
        params ["_icon", "_count", "_row", "_tooltip", ["_xOffset", 0]];
        private _ctrl = _display ctrlCreate ["A3A_PictureStroke", -1, _crewControlsGroup];
        _ctrl ctrlSetPosition [_xOffset * GRID_W, _row * 4.5 * GRID_H, 3 * GRID_W, 3 * GRID_H];
        _ctrl ctrlSetText _icon;
        _ctrl ctrlSetTooltip _tooltip;
        _ctrl ctrlCommit 0;
        if (_count > 1) then {
            private _text = _display ctrlCreate ["A3A_InfoTextLeft", -1, _crewControlsGroup];
            _text ctrlSetPosition [(_xOffset + 3) * GRID_W, _row * 4.5 * GRID_H, 3 * GRID_W, 3 * GRID_H];
            _text ctrlSetText str _count;
            _text ctrlCommit 0;
        };
    };

    private _row = 0;
    if (_driver > 0) then { [A3A_Icon_Driver, _driver, _row, localize "STR_antistasi_dialogs_buy_vehicle_driver_tooltip"] call _fnc_crewIcon };
    if (_coPilot > 0) then { [A3A_Icon_Driver, _coPilot, _row, localize "STR_antistasi_dialogs_buy_vehicle_copilot_tooltip", 5] call _fnc_crewIcon };
    if (_driver > 0 || _coPilot > 0) then { _row = _row + 1 };
    if (_commander > 0) then { [A3A_Icon_Commander, _commander, _row, localize "STR_antistasi_dialogs_buy_vehicle_commander_tooltip"] call _fnc_crewIcon; _row = _row + 1 };
    if (_gunners > 0) then { [A3A_Icon_Gunner, _gunners, _row, format [localize "STR_antistasi_dialogs_buy_vehicle_gunner_amount_tooltip", _gunners]] call _fnc_crewIcon; _row = _row + 1 };
    if (_passengers > 0) then { [A3A_Icon_Cargo, _passengers, _row, format [localize "STR_antistasi_dialogs_buy_vehicle_passenger_amount_tooltip", _passengers]] call _fnc_crewIcon };
    if (_passengersFFV > 0) then { [A3A_Icon_FFV, _passengersFFV, _row, format [localize "STR_antistasi_dialogs_buy_vehicle_ffv_amount_tooltip", _passengersFFV], 7] call _fnc_crewIcon };

    _itemControlsGroup ctrlSetFade 0;
    _itemControlsGroup ctrlCommit 0.1;
    _added = _added + 1;
} forEach A3A_junkyardStock;

Debug_1("Junkyard dialog built with %1 cards", _added);
