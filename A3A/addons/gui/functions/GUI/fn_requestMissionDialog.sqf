/*
Maintainer: Shoter
    Handles the mission board dialog (A3A_RequestMissionDialog).
    The server keeps the board and publishes it as A3A_missionBoardView (see A3A_tasks_fnc_boardPublish);
    this fills the table from it, shows details and the reward of the selected mission, and sends the pick
    to the server. While the dialog is open it refreshes itself when the board changes.

Arguments:
    <STRING> Mode: "onLoad", "fillList", "selectionChanged" or "accept"

Return Value:
    <nil>

Scope: Clients
Environment: Scheduled for onLoad, Unscheduled for the rest
Public: No
Dependencies:
    A3A_missionBoardView, A3A_missionBoardNextUpdate, A3A_tasks_fnc_boardAccept

Example:
    ["onLoad"] spawn A3A_GUI_fnc_requestMissionDialog;
*/

#include "..\..\dialogues\ids.inc"
#include "..\..\dialogues\defines.hpp"
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

#define BOARD_CATEGORIES ["AS", "CONVOY", "DES", "CON", "LOG", "SUPP", "RES"]
#define BOARD_CATEGORY_NAMES ["assassination", "convoy", "destroy", "conquest", "logistics", "support", "rescue"]

params [["_mode", "onLoad"], ["_params", []]];

private _display = findDisplay A3A_IDD_REQUESTMISSIONDIALOG;
if (isNull _display) exitWith {};

private _fnc_categoryName = {
    private _index = BOARD_CATEGORIES find _this;
    if (_index == -1) exitWith { _this };
    localize ("STR_antistasi_dialogs_mission_request_" + (BOARD_CATEGORY_NAMES # _index));
};

private _fnc_missionName = {
    params ["_nameKey", "_hard"];
    private _name = localize _nameKey;
    if (_hard) then { _name = format [localize "STR_antistasi_dialogs_mission_board_hard_name", _name] };
    _name;
};

// Short reward for the table, e.g. "600 € + 600 € pay" or "100 € + 40 € pay + 2 HR per POW"
private _fnc_rewardShort = {
    params ["_money", "_points", "_hr", "_perUnitKey", "_noteKey"];
    private _parts = [];
    if (_money > 0) then { _parts pushBack format [localize "STR_antistasi_dialogs_mission_board_money", round _money] };
    if (_points > 0) then { _parts pushBack format [localize "STR_antistasi_dialogs_mission_board_pay", round (_points * 10)] };
    if (_hr > 0) then { _parts pushBack format [localize "STR_antistasi_dialogs_mission_board_hr", _hr] };
    private _text = _parts joinString " + ";
    if (_perUnitKey != "") then { _text = _text + " " + localize _perUnitKey };
    if (_noteKey != "") then { _text = ([_text, localize _noteKey] select { _x != "" }) joinString " + " };
    _text;
};

private _list = _display displayCtrl A3A_IDC_MISSIONBOARD_LIST;
private _details = _display displayCtrl A3A_IDC_MISSIONBOARD_DETAILS;
private _acceptButton = _display displayCtrl A3A_IDC_MISSIONBOARD_ACCEPT;

switch (_mode) do
{
    case ("onLoad"):
    {
        private _filter = _display displayCtrl A3A_IDC_MISSIONBOARD_FILTER;
        private _index = _filter lbAdd localize "STR_antistasi_dialogs_mission_board_all";
        _filter lbSetData [_index, ""];
        {
            _index = _filter lbAdd (_x call _fnc_categoryName);
            _filter lbSetData [_index, _x];
        } forEach BOARD_CATEGORIES;
        _filter lbSetCurSel 0;          // fires fillList

        // Countdown to the next missions, and refill when the server publishes a new board
        private _nextUpdateText = _display displayCtrl A3A_IDC_MISSIONBOARD_NEXTUPDATE;
        while { !isNull _display } do {
            private _next = missionNamespace getVariable ["A3A_missionBoardNextUpdate", -1];
            private _minutes = ceil ((_next - ([time, serverTime] select isMultiplayer)) / 60);
            _nextUpdateText ctrlSetText (if (_next < 0) then { "" } else {
                format [localize "STR_antistasi_dialogs_mission_board_next", 1 max _minutes]
            });
            if (_display getVariable ["shownBoard", []] isNotEqualTo (missionNamespace getVariable ["A3A_missionBoardView", []])) then {
                ["fillList"] call FUNC(requestMissionDialog);
            };
            sleep 1;
        };
    };

    case ("fillList"):
    {
        private _filter = _display displayCtrl A3A_IDC_MISSIONBOARD_FILTER;
        private _category = _filter lbData (lbCurSel _filter max 0);
        private _board = missionNamespace getVariable ["A3A_missionBoardView", []];
        _display setVariable ["shownBoard", _board];

        // Keep the selected mission selected across refreshes
        private _selectedId = -1;
        if (lnbCurSelRow _list >= 0) then { _selectedId = _list lnbValue [lnbCurSelRow _list, 0] };

        // Category order of the filter, then name, then location. The unique id keeps sort away from the row itself.
        private _rows = (_board select { _category == "" or { _x # 2 == _category } }) apply {
            [BOARD_CATEGORIES find (_x # 2), [_x # 1, _x # 5] call _fnc_missionName, [_x # 3] call A3A_fnc_localizar, _x # 0, _x]
        };
        _rows sort true;

        lnbClear _list;
        private _selectRow = -1;
        {
            _x params ["", "_name", "_location", "_id", "_row"];
            _row params ["", "", "_rowCategory", "", "_reward"];
            private _index = _list lnbAddRow [_name, _rowCategory call _fnc_categoryName, _location, _reward call _fnc_rewardShort];
            _list lnbSetValue [[_index, 0], _id];
            if (_row # 5) then { _list lnbSetColor [[_index, 0], A3A_COLOR_UNDERSTRENGTH_SQF] };
            if (_id == _selectedId) then { _selectRow = _index };
        } forEach _rows;

        _list lnbSetCurSelRow _selectRow;
        ["selectionChanged"] call FUNC(requestMissionDialog);
    };

    case ("selectionChanged"):
    {
        private _rowIndex = lnbCurSelRow _list;
        private _id = if (_rowIndex >= 0) then { _list lnbValue [_rowIndex, 0] } else { -1 };
        private _board = missionNamespace getVariable ["A3A_missionBoardView", []];
        private _row = _board select { _x # 0 == _id };
        _acceptButton ctrlEnable (_row isNotEqualTo []);

        if (_row isEqualTo []) exitWith {
            private _key = ["STR_antistasi_dialogs_mission_board_pick", "STR_antistasi_dialogs_mission_board_empty"] select ((lnbSize _list) # 0 == 0);
            _details ctrlSetStructuredText parseText localize _key;
        };

        (_row # 0) params ["", "_nameKey", "_category", "_marker", "_reward", "_hard", "_origin"];
        _reward params ["_money", "_points", "_hr", "_perUnitKey", "_noteKey"];

        private _lines = [];
        private _place = [_marker] call A3A_fnc_localizar;
        if (_origin != "") then { _place = format [localize "STR_antistasi_dialogs_mission_board_route", [_origin] call A3A_fnc_localizar, _place] };
        _lines pushBack format ["<t size='1.2'>%1</t>   %2, %3", [_nameKey, _hard] call _fnc_missionName, _category call _fnc_categoryName, _place];

        private _perUnit = if (_perUnitKey == "") then { "" } else { " " + localize _perUnitKey };
        if (_money > 0) then { _lines pushBack format [localize "STR_antistasi_dialogs_mission_board_detail_money", round _money, _perUnit] };
        if (_points > 0) then { _lines pushBack format [localize "STR_antistasi_dialogs_mission_board_detail_pay", round (_points * 10), _perUnit] };
        if (_hr > 0) then { _lines pushBack format [localize "STR_antistasi_dialogs_mission_board_detail_hr", _hr, _perUnit] };
        if (_noteKey != "") then { _lines pushBack format [localize "STR_antistasi_dialogs_mission_board_detail_note", localize _noteKey] };
        _lines pushBack localize (["STR_antistasi_dialogs_mission_board_detail_normal", "STR_antistasi_dialogs_mission_board_detail_hard"] select _hard);

        _details ctrlSetStructuredText parseText (_lines joinString "<br/>");
    };

    case ("accept"):
    {
        private _rowIndex = lnbCurSelRow _list;
        if (_rowIndex < 0) exitWith {};

        if !(([player] call A3A_fnc_isMember) || (player isEqualTo theBoss)) exitWith
        {
            [localize "STR_antistasi_dialogs_mission_request_title", localize "STR_antistasi_dialogs_mission_request_noCommander"] call A3A_fnc_customHint;
            closeDialog 2;
        };

        private _id = _list lnbValue [_rowIndex, 0];
        closeDialog 1;
        [_id, player, clientOwner] remoteExec ["A3A_tasks_fnc_boardAccept", 2];
    };

    default
    {
        Error_1("Mission board dialog mode does not exist: %1", _mode);
    };
};
