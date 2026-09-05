/*
Maintainer: Shoter
    Handles updating, sorting and controls on the Players tab of the Main dialog and its Details view.
    Lists every player that ever joined the campaign (online and offline) with kills, deaths, K/D and time online,
    one line of controls per player with a Details button. The rows come from the server (A3A_fnc_playerStats_request),
    the details of one player from A3A_fnc_playerStats_requestDetails; both answer through this function.

Arguments:
    <STRING> Mode
    <ARRAY<ANY>> Array of params for the mode when applicable. Params for specific modes are documented in the modes.

Return Value:
    Nothing

Scope: Clients, Local Arguments, Local Effect
Environment: Unscheduled
Public: No
Dependencies:
    None

Example:
    ["update"] call FUNC(playerStatsTab);
    ["sortBy", [1]] call FUNC(playerStatsTab); // sort by the Kills column
    ["showDetails", ["76561198000000000"]] call FUNC(playerStatsTab);

License: APL-ND

*/

#include "..\..\dialogues\ids.inc"
#include "..\..\dialogues\defines.hpp"
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

// Every row is a set of controls, so the table is capped to keep the dialog responsive on long-running servers
#define MAX_ROWS 100
#define ROW_HEIGHT (4 * GRID_H)

params [["_mode","onLoad"], ["_params",[]]];

private _display = findDisplay A3A_IDD_MAINDIALOG;
private _tab = _display displayCtrl A3A_IDC_PLAYERSTATSTAB;
private _list = _display displayCtrl A3A_IDC_PLAYERSTATSLIST;
private _status = _display displayCtrl A3A_IDC_PLAYERSTATSSTATUSTEXT;

// Column index -> [header button IDC, header stringtable key]
private _columns = [
    [A3A_IDC_PLAYERSTATSHEADER_NAME, "STR_antistasi_dialogs_main_towns_name_label"],
    [A3A_IDC_PLAYERSTATSHEADER_KILLS, "STR_antistasi_dialogs_main_playerstats_kills_label"],
    [A3A_IDC_PLAYERSTATSHEADER_DEATHS, "STR_antistasi_dialogs_main_playerstats_deaths_label"],
    [A3A_IDC_PLAYERSTATSHEADER_KD, "STR_antistasi_dialogs_main_playerstats_kd_label"],
    [A3A_IDC_PLAYERSTATSHEADER_TIME, "STR_antistasi_dialogs_main_playerstats_time_online_label"]
];

private _fnc_formatTime = {
    params ["_seconds"];
    if (_seconds < 60) exitWith { "0" + localize "STR_antistasi_timeSpan_minutes_abbr" };
    [_seconds, 1, 1, false, 2, false, true] call A3A_fnc_timeSpan_format;
};

private _fnc_formatDate = {
    params ["_date"];
    if (count _date < 3) exitWith { "-" };
    format ["%1-%2-%3", _date#0, (str (_date#1)) call A3A_fnc_pad_2Digits, (str (_date#2)) call A3A_fnc_pad_2Digits];
};

private _fnc_formatKD = {
    params ["_kills", "_deaths"];
    (_kills / (_deaths max 1)) toFixed 2;
};

// Numbers below zero mean "unknown" in the details payload
private _fnc_formatNumber = {
    if (_this < 0) then { "-" } else { str _this };
};

switch (_mode) do
{
    case ("update"):
    {
        Trace("Updating Players tab");
        if (isNull _display) exitWith {};

        // Show the last answer while the server prepares a fresh one
        if ((_tab getVariable ["playerRows", []]) isEqualTo []) then {
            { ctrlDelete _x } forEach allControls _list;
            _status ctrlSetText localize "STR_antistasi_dialogs_main_playerstats_loading";
        } else {
            ["render"] call FUNC(playerStatsTab);
        };
        [clientOwner] remoteExecCall ["A3A_fnc_playerStats_request", 2];
    };

    case ("refresh"):
    {
        _tab setVariable ["playerRows", []];
        ["update"] call FUNC(playerStatsTab);
    };

    case ("dataReceived"):
    {
        // Takes 1 parameter: <ARRAY> rows [uid, name, kills, deaths, timeOnline, online, member] sent by the server
        _params params [["_rows", [], [[]]]];
        if (isNull _display) exitWith {};
        _tab setVariable ["playerRows", _rows];
        ["render"] call FUNC(playerStatsTab);
    };

    case ("render"):
    {
        if (isNull _display) exitWith {};
        private _rows = _tab getVariable ["playerRows", []];
        private _sortColumn = _tab getVariable ["sortColumn", 1];
        private _sortAscending = _tab getVariable ["sortAscending", false];
        private _filter = toLower ctrlText (_display displayCtrl A3A_IDC_PLAYERSTATSFILTEREDIT);

        // [sortKey, lower-cased name, uid, row]; the UID is unique so the row arrays are never compared
        private _sorted = [];
        {
            _x params ["_uid", "_name", "_kills", "_deaths", "_timeOnline"];
            if (_filter != "" && {(toLower _name) find _filter == -1}) then { continue };
            private _sortKeys = [toLower _name, _kills, _deaths, _kills / (_deaths max 1), _timeOnline];
            _sorted pushBack [_sortKeys select _sortColumn, toLower _name, _uid, _x];
        } forEach _rows;
        _sorted sort _sortAscending;

        { ctrlDelete _x } forEach allControls _list;

        private _detailsText = localize "STR_antistasi_dialogs_main_playerstats_details_button";
        private _textColor = [A3A_COLOR_TEXT] call FUNC(configColorToArray);
        private _shown = (count _sorted) min MAX_ROWS;
        for "_i" from 0 to _shown - 1 do {
            (_sorted select _i select 3) params ["_uid", "_name", "_kills", "_deaths", "_timeOnline", "_online", "_member"];
            private _y = _i * ROW_HEIGHT;
            private _color = if (_online) then { _textColor } else { A3A_COLOR_TEXT_DARKER_SQF };
            private _nameColor = if (_online && _member) then { A3A_COLOR_MEMBER_SQF } else { _color };

            // Positions are relative to the list group, 6 grid units on the right are left for the scrollbar
            {
                _x params ["_class", "_xPos", "_width", "_text", "_cellColor"];
                private _ctrl = _display ctrlCreate [_class, -1, _list];
                _ctrl ctrlSetPosition [_xPos * GRID_W, _y, _width * GRID_W, ROW_HEIGHT];
                _ctrl ctrlCommit 0;
                _ctrl ctrlSetText _text;
                _ctrl ctrlSetTextColor _cellColor;
            } forEach [
                ["A3A_Text", 1, 46, _name, _nameColor],
                ["A3A_TextRight", 47, 14, str _kills, _color],
                ["A3A_TextRight", 62, 14, str _deaths, _color],
                ["A3A_TextRight", 77, 14, [_kills, _deaths] call _fnc_formatKD, _color],
                ["A3A_TextRight", 92, 28, [_timeOnline] call _fnc_formatTime, _color]
            ];

            private _button = _display ctrlCreate ["A3A_Button_Small", -1, _list];
            _button ctrlSetPosition [121 * GRID_W, _y, 16 * GRID_W, ROW_HEIGHT];
            _button ctrlCommit 0;
            _button ctrlSetText _detailsText;
            _button setVariable ["A3A_params", _uid];
            _button ctrlAddEventHandler ["ButtonClick", {
                ["showDetails", [(_this select 0) getVariable "A3A_params"]] call A3A_GUI_fnc_playerStatsTab;
            }];
        };

        // Status line under the table
        private _statusText = switch (true) do {
            case (_rows isEqualTo []): { localize "STR_antistasi_dialogs_main_playerstats_no_data" };
            case (_shown < count _sorted): { format [localize "STR_antistasi_dialogs_main_playerstats_showing", _shown, count _sorted] };
            default { format [localize "STR_antistasi_dialogs_main_playerstats_count", count _sorted] };
        };
        _status ctrlSetText _statusText;

        // Header captions with a sort direction indicator on the active column
        private _arrow = toString [[9660, 9650] select _sortAscending];
        {
            _x params ["_idc", "_key"];
            private _caption = localize _key;
            if (_forEachIndex == _sortColumn) then { _caption = _caption + " " + _arrow };
            (_display displayCtrl _idc) ctrlSetText _caption;
        } forEach _columns;
    };

    case ("sortBy"):
    {
        // Takes 1 parameter: <NUMBER> column index to sort by. Clicking the active column flips the direction.
        _params params [["_column", 0, [0]]];

        if (_column == (_tab getVariable ["sortColumn", 1])) then {
            _tab setVariable ["sortAscending", !(_tab getVariable ["sortAscending", false])];
        } else {
            _tab setVariable ["sortColumn", _column];
            // Names read best A-Z, numbers highest first
            _tab setVariable ["sortAscending", _column == 0];
        };

        ["render"] call FUNC(playerStatsTab);
    };

    case ("showDetails"):
    {
        // Takes 1 parameter: <STRING> UID of the player to show
        _params params [["_uid", "", [""]]];
        if (_uid == "") exitWith {};
        _display setVariable ["A3A_playerStatsDetailsUID", _uid];
        ["switchTab", ["playerstatsdetails"]] call FUNC(mainDialog);
    };

    case ("updateDetails"):
    {
        Trace("Updating Players details");
        if (isNull _display) exitWith {};
        private _uid = _display getVariable ["A3A_playerStatsDetailsUID", ""];

        // Back button returns to the table
        private _backButton = _display displayCtrl A3A_IDC_MAINDIALOGBACKBUTTON;
        _backButton ctrlRemoveAllEventHandlers "MouseButtonClick";
        _backButton ctrlAddEventHandler ["MouseButtonClick", {
            ["switchTab", ["playerstats"]] call FUNC(mainDialog);
        }];
        _backButton ctrlShow true;

        // Name from the cached row, the values are blanked until the server answers
        private _rows = _tab getVariable ["playerRows", []];
        private _rowIndex = _rows findIf { (_x select 0) == _uid };
        private _name = if (_rowIndex == -1) then { _uid } else { _rows select _rowIndex select 1 };
        (_display displayCtrl A3A_IDC_PLAYERDETAILS_NAME) ctrlSetText _name;
        (_display displayCtrl A3A_IDC_PLAYERDETAILS_STATUS) ctrlSetText "";
        {
            (_display displayCtrl _x) ctrlSetText "...";
        } forEach [
            A3A_IDC_PLAYERDETAILS_KILLS, A3A_IDC_PLAYERDETAILS_VEHICLEKILLS, A3A_IDC_PLAYERDETAILS_AIRKILLS,
            A3A_IDC_PLAYERDETAILS_CIVILIANKILLS, A3A_IDC_PLAYERDETAILS_FRIENDLYKILLS, A3A_IDC_PLAYERDETAILS_PLAYERKILLS,
            A3A_IDC_PLAYERDETAILS_LONGESTKILL, A3A_IDC_PLAYERDETAILS_DEATHS, A3A_IDC_PLAYERDETAILS_KD,
            A3A_IDC_PLAYERDETAILS_TIMESDOWNED, A3A_IDC_PLAYERDETAILS_REVIVES, A3A_IDC_PLAYERDETAILS_SESSIONS,
            A3A_IDC_PLAYERDETAILS_FIRSTSEEN, A3A_IDC_PLAYERDETAILS_LASTSEEN, A3A_IDC_PLAYERDETAILS_TIMEONLINE,
            A3A_IDC_PLAYERDETAILS_CURRENTSESSION, A3A_IDC_PLAYERDETAILS_RANK, A3A_IDC_PLAYERDETAILS_SCORE,
            A3A_IDC_PLAYERDETAILS_MONEY, A3A_IDC_PLAYERDETAILS_MONEYEARNED, A3A_IDC_PLAYERDETAILS_MISSIONS
        ];

        // The Steam UID is for admins only, like on the Player Management tab
        private _isAdmin = [] call FUNCMAIN(isLocalAdmin);
        (_display displayCtrl A3A_IDC_PLAYERDETAILS_UIDLABEL) ctrlShow _isAdmin;
        (_display displayCtrl A3A_IDC_PLAYERDETAILS_UID) ctrlShow _isAdmin;
        (_display displayCtrl A3A_IDC_PLAYERDETAILS_UID) ctrlSetText ([_uid, ""] select !_isAdmin);

        [clientOwner, _uid] remoteExecCall ["A3A_fnc_playerStats_requestDetails", 2];
    };

    case ("detailsReceived"):
    {
        // Takes 1 parameter: <ARRAY> [uid, stats hashmap, online, member, currentSession, rank, score, money, missions] sent by the server
        _params params [["_details", [], [[]]]];
        if (isNull _display) exitWith {};
        _details params [
            ["_uid", "", [""]],
            ["_stats", createHashMap, [createHashMap]],
            ["_online", false, [false]],
            ["_member", false, [false]],
            ["_currentSession", -1, [0]],
            ["_rank", "", [""]],
            ["_score", -1, [0]],
            ["_money", -1, [0]],
            ["_missions", -1, [0]]
        ];
        // A late answer for a player that is no longer shown
        if (_uid == "" || {_uid != (_display getVariable ["A3A_playerStatsDetailsUID", ""])}) exitWith {};

        private _name = _stats getOrDefault ["name", ""];
        if (_name == "") then { _name = _uid };
        (_display displayCtrl A3A_IDC_PLAYERDETAILS_NAME) ctrlSetText _name;

        private _statusCtrl = _display displayCtrl A3A_IDC_PLAYERDETAILS_STATUS;
        _statusCtrl ctrlSetText format ["%1, %2",
            localize (["STR_antistasi_dialogs_main_playerstats_offline", "STR_antistasi_dialogs_main_playerstats_online"] select _online),
            localize (["STR_antistasi_dialogs_main_playerstats_guest", "STR_antistasi_dialogs_main_playerstats_member"] select _member)
        ];
        _statusCtrl ctrlSetTextColor (if (_online) then { [A3A_COLOR_TEXT] call FUNC(configColorToArray) } else { A3A_COLOR_TEXT_DARKER_SQF });

        private _kills = _stats getOrDefault ["kills", 0];
        private _deaths = _stats getOrDefault ["deaths", 0];

        // Rank names come from CfgRanks, fall back to the raw rank string
        private _rankName = _rank;
        if (_rank != "") then {
            private _displayName = [_rank, "displayName"] call BIS_fnc_rankParams;
            if (_displayName isEqualType "" && {_displayName != ""}) then { _rankName = _displayName };
        };

        private _moneyFormat = localize "STR_antistasi_dialogs_main_playerstats_money_value";
        {
            _x params ["_idc", "_text"];
            (_display displayCtrl _idc) ctrlSetText _text;
        } forEach [
            [A3A_IDC_PLAYERDETAILS_KILLS, str _kills],
            [A3A_IDC_PLAYERDETAILS_VEHICLEKILLS, str (_stats getOrDefault ["vehicleKills", 0])],
            [A3A_IDC_PLAYERDETAILS_AIRKILLS, str (_stats getOrDefault ["airKills", 0])],
            [A3A_IDC_PLAYERDETAILS_CIVILIANKILLS, str (_stats getOrDefault ["civilianKills", 0])],
            [A3A_IDC_PLAYERDETAILS_FRIENDLYKILLS, str (_stats getOrDefault ["friendlyKills", 0])],
            [A3A_IDC_PLAYERDETAILS_PLAYERKILLS, str (_stats getOrDefault ["playerKills", 0])],
            [A3A_IDC_PLAYERDETAILS_LONGESTKILL, format ["%1 m", _stats getOrDefault ["longestKill", 0]]],
            [A3A_IDC_PLAYERDETAILS_DEATHS, str _deaths],
            [A3A_IDC_PLAYERDETAILS_KD, [_kills, _deaths] call _fnc_formatKD],
            [A3A_IDC_PLAYERDETAILS_TIMESDOWNED, str (_stats getOrDefault ["timesDowned", 0])],
            [A3A_IDC_PLAYERDETAILS_REVIVES, str (_stats getOrDefault ["revives", 0])],
            [A3A_IDC_PLAYERDETAILS_SESSIONS, str (_stats getOrDefault ["sessions", 0])],
            [A3A_IDC_PLAYERDETAILS_FIRSTSEEN, [_stats getOrDefault ["firstSeen", []]] call _fnc_formatDate],
            [A3A_IDC_PLAYERDETAILS_LASTSEEN, [_stats getOrDefault ["lastSeen", []]] call _fnc_formatDate],
            [A3A_IDC_PLAYERDETAILS_TIMEONLINE, [_stats getOrDefault ["timeOnline", 0]] call _fnc_formatTime],
            [A3A_IDC_PLAYERDETAILS_CURRENTSESSION, [_currentSession max 0] call _fnc_formatTime],
            [A3A_IDC_PLAYERDETAILS_RANK, _rankName],
            [A3A_IDC_PLAYERDETAILS_SCORE, _score call _fnc_formatNumber],
            [A3A_IDC_PLAYERDETAILS_MONEY, if (_money < 0) then { "-" } else { format [_moneyFormat, _money] }],
            [A3A_IDC_PLAYERDETAILS_MONEYEARNED, format [_moneyFormat, _stats getOrDefault ["moneyEarned", 0]]],
            [A3A_IDC_PLAYERDETAILS_MISSIONS, _missions call _fnc_formatNumber]
        ];

        // The running session only makes sense for connected players
        (_display displayCtrl A3A_IDC_PLAYERDETAILS_CURRENTSESSIONLABEL) ctrlShow _online;
        (_display displayCtrl A3A_IDC_PLAYERDETAILS_CURRENTSESSION) ctrlShow _online;
    };

    default
    {
        // Log error if attempting to call a mode that doesn't exist
        Error_1("Players tab mode does not exist: %1", _mode);
    };
};
