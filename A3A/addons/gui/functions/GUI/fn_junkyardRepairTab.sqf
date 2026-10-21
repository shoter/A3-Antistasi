/*
Maintainer: Shoter
    Fills the Vehicle repair tab of the Junkyard dialog and keeps it current while the dialog is open.
    One compact row per vehicle in A3A_junkyardRepairs: repaired vehicles first (soonest to leave on top), then the
    repair queue (soonest ready on top). Each row has a preview, name and weapons, a countdown with a progress bar,
    the price and a buy button that only works once the repair is done. Rows sit in a scrolling group, so the list
    can be long. Every 2 seconds the countdowns are updated; when the shop changes or a vehicle finishes or leaves,
    the list is rebuilt, keeping the scroll position.

Arguments:
    <STRING> Mode, only possible value is "onLoad"

Return Value:
    Nothing

Scope: Clients, Local Arguments, Local Effect
Environment: Scheduled
Public: No
Dependencies:
    A3A_junkyardRepairs, A3A_junkyardRepairBuyWindow, A3A_fnc_junkyardClock, A3A_fnc_getVehicleWeapons, A3A_fnc_junkyardRepairBuy

Example:
    ["onLoad"] spawn A3A_GUI_fnc_junkyardRepairTab;

License: APL-ND
*/

#include "..\..\dialogues\ids.inc"
#include "..\..\dialogues\defines.hpp"
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_mode", "onLoad"]];
if (_mode != "onLoad") exitWith { Error_1("JunkyardRepairTab mode does not exist: %1", _mode) };

private _display = findDisplay A3A_IDD_JUNKYARDDIALOG;
if (isNull _display) exitWith {};
private _scrollGroup = _display displayCtrl A3A_IDC_JUNKYARDREPAIRGROUP;
private _infoText = _display displayCtrl A3A_IDC_JUNKYARDREPAIRINFOTEXT;

// Row geometry in grid units, relative to the list group inside the scrolling group
#define ROW_X 2
#define ROW_W 150
#define ROW_H 10
#define ROW_GAP 1
#define HEADER_H 5

private _colorRepair = [0.9, 0.7, 0.2, 1];
private _colorReady = [0.3, 0.75, 0.3, 1];
private _weaponsCache = createHashMap;

private _fnc_timeText = {
    [(_this max 0), 1, 1, false, 2, false, true] call A3A_fnc_timeSpan_format;
};

// Returns [<ARRAY> ready entries, <ARRAY> queued entries], expired ones left out, both sorted for display
private _fnc_split = {
    private _now = call A3A_fnc_junkyardClock;
    private _live = (missionNamespace getVariable ["A3A_junkyardRepairs", []]) select { _x#5 > _now and {isClass (configFile >> "CfgVehicles" >> _x#1)} };
    [
        [_live select { _x#4 <= _now }, [], { _x#5 }, "ASCEND"] call BIS_fnc_sortBy,
        [_live select { _x#4 > _now }, [], { _x#4 }, "ASCEND"] call BIS_fnc_sortBy
    ];
};

// Countdown text and bar of one row. Record: [entry, status text, bar fill, ready]
private _fnc_updateRow = {
    params ["_entry", "_status", "_fill", "_ready"];
    _entry params ["", "", "", "_queuedAt", "_readyAt", "_removeAt"];
    private _now = call A3A_fnc_junkyardClock;
    private _fraction = if (_ready) then {
        _status ctrlSetText format [localize "STR_antistasi_dialogs_junkyard_repair_ready_status", (_removeAt - _now) call _fnc_timeText];
        (_removeAt - _now) / ((_removeAt - _readyAt) max 1)
    } else {
        _status ctrlSetText format [localize "STR_antistasi_dialogs_junkyard_repair_queue_status", (_readyAt - _now) call _fnc_timeText];
        (_now - _queuedAt) / ((_readyAt - _queuedAt) max 1)
    };
    _fill ctrlSetPositionW (38 * GRID_W * ((_fraction max 0) min 1));
    _fill ctrlCommit 0;
};

private _fnc_header = {
    params ["_list", "_y", "_text"];
    private _ctrl = _display ctrlCreate ["A3A_SectionLabelRight", -1, _list];
    _ctrl ctrlSetPosition [ROW_X * GRID_W, _y, ROW_W * GRID_W, HEADER_H * GRID_H];
    _ctrl ctrlSetText _text;
    _ctrl ctrlCommit 0;
    _y + (HEADER_H + ROW_GAP) * GRID_H;
};

private _fnc_row = {
    params ["_list", "_y", "_entry", "_ready"];
    _entry params ["_id", "_className", "_price"];
    private _configClass = configFile >> "CfgVehicles" >> _className;
    private _displayName = getText (_configClass >> "displayName");

    private _weaponsText = _weaponsCache getOrDefaultCall [_className, {
        private _weapons = [_className] call A3A_fnc_getVehicleWeapons;
        if (_weapons isEqualTo []) then {
            localize "STR_antistasi_dialogs_junkyard_unarmed"
        } else {
            format [localize "STR_antistasi_dialogs_junkyard_weapons", _weapons joinString ", "]
        };
    }, true];

    private _row = _display ctrlCreate ["A3A_ControlsGroupNoScrollbars", -1, _list];
    _row ctrlSetPosition [ROW_X * GRID_W, _y, ROW_W * GRID_W, ROW_H * GRID_H];
    _row ctrlCommit 0;

    private _background = _display ctrlCreate ["A3A_Background", -1, _row];
    _background ctrlSetPosition [0, 0, ROW_W * GRID_W, ROW_H * GRID_H];
    _background ctrlSetBackgroundColor [0, 0, 0, 0.3];
    _background ctrlCommit 0;

    // Editor preview, or the vehicle icon when the class has none
    private _picture = _display ctrlCreate ["A3A_Picture", -1, _row];
    _picture ctrlSetPosition [1 * GRID_W, 0.5 * GRID_H, 16 * GRID_W, 9 * GRID_H];
    private _editorPreview = getText (_configClass >> "editorPreview");
    _picture ctrlSetText ([getText (_configClass >> "picture"), _editorPreview] select (fileExists _editorPreview));
    _picture ctrlCommit 0;

    private _nameText = _display ctrlCreate ["A3A_StructuredText", -1, _row];
    _nameText ctrlSetPosition [18 * GRID_W, 0.5 * GRID_H, 52 * GRID_W, 9 * GRID_H];
    _nameText ctrlSetStructuredText parseText format ["<t size='0.9'>%1</t><br/><t size='0.7' color='#B3B3B3'>%2</t>", _displayName, _weaponsText];
    _nameText ctrlSetTooltip _weaponsText;
    _nameText ctrlCommit 0;

    private _status = _display ctrlCreate ["A3A_InfoTextLeft", -1, _row];
    _status ctrlSetPosition [72 * GRID_W, 1 * GRID_H, 40 * GRID_W, 4 * GRID_H];
    _status ctrlCommit 0;

    private _barBackground = _display ctrlCreate ["A3A_Background", -1, _row];
    _barBackground ctrlSetPosition [72 * GRID_W, 6 * GRID_H, 38 * GRID_W, 1.5 * GRID_H];
    _barBackground ctrlSetBackgroundColor [0, 0, 0, 0.6];
    _barBackground ctrlCommit 0;

    private _fill = _display ctrlCreate ["A3A_Background", -1, _row];
    _fill ctrlSetPosition [72 * GRID_W, 6 * GRID_H, 0, 1.5 * GRID_H];
    _fill ctrlSetBackgroundColor ([_colorRepair, _colorReady] select _ready);
    _fill ctrlCommit 0;

    private _priceText = _display ctrlCreate ["A3A_InfoTextRight", -1, _row];
    _priceText ctrlSetPosition [112 * GRID_W, 3 * GRID_H, 17 * GRID_W, 4 * GRID_H];
    _priceText ctrlSetText format ["%1 €", _price];
    _priceText ctrlCommit 0;

    private _button = _display ctrlCreate ["A3A_Button", -1, _row];
    _button ctrlSetPosition [131 * GRID_W, 1.5 * GRID_H, 18 * GRID_W, 7 * GRID_H];
    _button ctrlSetText localize "STR_antistasi_dialogs_junkyard_repair_buy";
    _button ctrlEnable _ready;
    _button ctrlSetTooltip (if (_ready) then {
        format [localize "STR_antistasi_dialogs_junkyard_repair_buy_tooltip", _displayName, _price]
    } else {
        format [localize "STR_antistasi_dialogs_junkyard_repair_wait_tooltip", _price]
    });
    _button setVariable ["entryId", _id];
    _button ctrlAddEventHandler ["ButtonClick", {
        params ["_control"];
        private _display = findDisplay A3A_IDD_JUNKYARDDIALOG;
        private _useFactionFunds = ([player] call A3A_fnc_isCommandStaff) && { cbChecked (_display displayCtrl A3A_IDC_JUNKYARDFACTIONFUNDS) };
        private _id = _control getVariable "entryId";
        closeDialog 2;
        [_id, _useFactionFunds] spawn A3A_fnc_junkyardRepairBuy;
    }];
    _button ctrlCommit 0;

    private _record = [_entry, _status, _fill, _ready];
    _record call _fnc_updateRow;
    _record;
};

// Builds the whole list in a fresh group (deleting a group deletes its rows). Returns [list group, row records]
private _fnc_build = {
    params ["_oldList", "_split"];
    _split params ["_ready", "_queue"];
    private _scroll = ctrlScrollValues _scrollGroup;
    if (!isNull _oldList) then { ctrlDelete _oldList };

    _infoText ctrlSetText format [localize "STR_antistasi_dialogs_junkyard_repair_info", count _ready, count _queue, A3A_junkyardRepairBuyWindow call _fnc_timeText];

    private _rowCount = count _ready + count _queue;
    private _sections = ([0, 1] select (_ready isNotEqualTo [])) + ([0, 1] select (_queue isNotEqualTo []));
    private _height = (ROW_GAP + _sections * (HEADER_H + ROW_GAP) + _rowCount * (ROW_H + ROW_GAP) + 2) * GRID_H;

    private _list = _display ctrlCreate ["A3A_ControlsGroupNoScrollbars", -1, _scrollGroup];
    _list ctrlSetPosition [0, 0, (ROW_X + ROW_W) * GRID_W, _height];
    _list ctrlCommit 0;

    private _records = [];
    if (_rowCount == 0) exitWith {
        private _emptyText = _display ctrlCreate ["A3A_InfoTextLeft", -1, _list];
        _emptyText ctrlSetPosition [7 * GRID_W, 5 * GRID_H, 140 * GRID_W, 4 * GRID_H];
        _emptyText ctrlSetText (localize "STR_antistasi_dialogs_junkyard_repair_empty");
        _emptyText ctrlCommit 0;
        [_list, _records];
    };

    private _y = ROW_GAP * GRID_H;
    {
        _x params ["_entries", "_isReady", "_headerKey"];
        if (_entries isEqualTo []) then { continue };
        _y = [_list, _y, format [localize _headerKey, count _entries]] call _fnc_header;
        {
            if (isNull _display) exitWith {};
            _records pushBack ([_list, _y, _x, _isReady] call _fnc_row);
            _y = _y + (ROW_H + ROW_GAP) * GRID_H;
        } forEach _entries;
    } forEach [
        [_ready, true, "STR_antistasi_dialogs_junkyard_repair_ready_header"],
        [_queue, false, "STR_antistasi_dialogs_junkyard_repair_queue_header"]
    ];

    _scrollGroup ctrlSetScrollValues [_scroll#0, -1];
    [_list, _records];
};

// The list is rebuilt when the shop data changes or a vehicle moves between the sections or leaves
private _fnc_signature = {
    params ["_split"];
    [missionNamespace getVariable ["A3A_junkyardRepairs", []], (_split#0) apply { _x#0 }, (_split#1) apply { _x#0 }];
};

private _split = call _fnc_split;
private _signature = [_split] call _fnc_signature;
([controlNull, _split] call _fnc_build) params ["_list", "_records"];
Debug_1("Junkyard repair tab built with %1 rows", count _records);

while { !isNull _display } do {
    uiSleep 2;
    if (isNull _display) exitWith {};
    _split = call _fnc_split;
    private _newSignature = [_split] call _fnc_signature;
    if (_newSignature isNotEqualTo _signature) then {
        _signature = _newSignature;
        ([_list, _split] call _fnc_build) params ["_newList", "_newRecords"];
        _list = _newList;
        _records = _newRecords;
    } else {
        { _x call _fnc_updateRow } forEach _records;
    };
};
