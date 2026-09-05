/*
Maintainer: Shoter
    Handles updating, sorting and controls on the Players tab of the Main dialog and its Details view.
    Lists every player that ever joined the campaign (online and offline) with kills, deaths, K/D and time online,
    one line of controls per player with a Details button. The rows come from the server (A3A_fnc_playerStats_request),
    the details of one player from A3A_fnc_playerStats_requestDetails; both answer through this function.
    The Details view is built at runtime inside a scrolling group: label/value sections, the movement and role tables
    and the per-weapon table with kills, shots and accuracy at the bottom.

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

// Details layout, grid units inside the scrolling group (138 usable, the rest is scrollbar)
#define DETAILS_LEFT 1
#define DETAILS_RIGHT 73
#define DETAILS_COLUMN_W 66
#define DETAILS_LABEL_W 38
#define DETAILS_ROW_STEP 5
#define DETAILS_SECTION_GAP 3

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

private _fnc_formatDistance = {
    params ["_metres"];
    if (_metres >= 1000) then { format ["%1 km", (_metres / 1000) toFixed 1] } else { format ["%1 m", round _metres] };
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

        // Name from the cached row, the panel stays empty until the server answers
        private _rows = _tab getVariable ["playerRows", []];
        private _rowIndex = _rows findIf { (_x select 0) == _uid };
        private _name = if (_rowIndex == -1) then { _uid } else { _rows select _rowIndex select 1 };
        (_display displayCtrl A3A_IDC_PLAYERDETAILS_NAME) ctrlSetText _name;
        (_display displayCtrl A3A_IDC_PLAYERDETAILS_STATUS) ctrlSetText "";
        { ctrlDelete _x } forEach allControls (_display displayCtrl A3A_IDC_PLAYERDETAILS_SCROLL);
        (_display displayCtrl A3A_IDC_PLAYERDETAILS_STATUSTEXT) ctrlSetText localize "STR_antistasi_dialogs_main_playerstats_loading";

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

        private _textColor = [A3A_COLOR_TEXT] call FUNC(configColorToArray);
        private _statusCtrl = _display displayCtrl A3A_IDC_PLAYERDETAILS_STATUS;
        _statusCtrl ctrlSetText format ["%1, %2",
            localize (["STR_antistasi_dialogs_main_playerstats_offline", "STR_antistasi_dialogs_main_playerstats_online"] select _online),
            localize (["STR_antistasi_dialogs_main_playerstats_guest", "STR_antistasi_dialogs_main_playerstats_member"] select _member)
        ];
        _statusCtrl ctrlSetTextColor (if (_online) then { _textColor } else { A3A_COLOR_TEXT_DARKER_SQF });
        (_display displayCtrl A3A_IDC_PLAYERDETAILS_STATUSTEXT) ctrlSetText "";

        private _scroll = _display displayCtrl A3A_IDC_PLAYERDETAILS_SCROLL;
        { ctrlDelete _x } forEach allControls _scroll;

        // Control factory, positions in grid units relative to the scrolling group
        private _fnc_add = {
            params ["_class", "_left", "_top", "_width", "_text", ["_tooltip", ""], ["_height", 4]];
            private _ctrl = _display ctrlCreate [_class, -1, _scroll];
            _ctrl ctrlSetPosition [_left * GRID_W, _top * GRID_H, _width * GRID_W, _height * GRID_H];
            _ctrl ctrlCommit 0;
            _ctrl ctrlSetText _text;
            if (_tooltip != "") then { _ctrl ctrlSetTooltip _tooltip };
            _ctrl
        };

        // A section title followed by label/value rows: [labelKey, valueText, tooltipKey]. Returns the next free top.
        private _fnc_column = {
            params ["_left", "_top", "_sectionKey", "_rows"];
            ["A3A_SectionLabelCenter", _left, _top, DETAILS_COLUMN_W, localize _sectionKey] call _fnc_add;
            _top = _top + DETAILS_ROW_STEP;
            {
                _x params ["_labelKey", "_value", ["_tooltipKey", ""]];
                private _tooltip = if (_tooltipKey == "") then { "" } else { localize _tooltipKey };
                ["A3A_Text", _left, _top, DETAILS_LABEL_W, localize _labelKey, _tooltip] call _fnc_add;
                ["A3A_TextRight", _left + DETAILS_LABEL_W, _top, DETAILS_COLUMN_W - DETAILS_LABEL_W, _value, _tooltip] call _fnc_add;
                _top = _top + DETAILS_ROW_STEP;
            } forEach _rows;
            _top
        };

        // A section title, a header line and text rows: columns [headerKey, x offset, width, rightAligned, tooltipKey]. Returns the next free top.
        private _fnc_table = {
            params ["_left", "_top", "_sectionKey", "_width", "_tableColumns", "_tableRows", ["_emptyKey", ""]];
            ["A3A_SectionLabelCenter", _left, _top, _width, localize _sectionKey] call _fnc_add;
            _top = _top + DETAILS_ROW_STEP;
            {
                _x params ["_headerKey", "_offset", "_columnWidth", "_rightAligned", ["_tooltipKey", ""]];
                private _tooltip = if (_tooltipKey == "") then { "" } else { localize _tooltipKey };
                private _header = [["A3A_Text", "A3A_TextRight"] select _rightAligned, _left + _offset, _top, _columnWidth, localize _headerKey, _tooltip] call _fnc_add;
                _header ctrlSetFontHeight GUI_TEXT_SIZE_SMALL;
                _header ctrlSetTextColor A3A_COLOR_TEXT_DARKER_SQF;
            } forEach _tableColumns;
            _top = _top + 4;
            if (_tableRows isEqualTo [] && {_emptyKey != ""}) then {
                ["A3A_Text", _left, _top, _width, localize _emptyKey] call _fnc_add;
                _top = _top + 4;
            };
            {
                private _cells = _x;
                {
                    _x params ["", "_offset", "_columnWidth", "_rightAligned"];
                    [["A3A_Text", "A3A_TextRight"] select _rightAligned, _left + _offset, _top, _columnWidth, _cells select _forEachIndex] call _fnc_add;
                } forEach _tableColumns;
                _top = _top + 4;
            } forEach _tableRows;
            _top
        };

        private _fnc_money = {
            params ["_amount"];
            if (_amount < 0) then { "-" } else { format [localize "STR_antistasi_dialogs_main_playerstats_money_value", _amount] };
        };

        private _fnc_weaponName = {
            params ["_class"];
            private _config = configFile >> "CfgWeapons" >> _class;
            if !(isClass _config) then { _config = configFile >> "CfgVehicles" >> _class };
            private _displayName = getText (_config >> "displayName");
            if (_displayName == "") then { _class } else { _displayName };
        };

        private _kills = _stats getOrDefault ["kills", 0];
        private _deaths = _stats getOrDefault ["deaths", 0];

        // Rank names come from CfgRanks, fall back to the raw rank string
        private _rankName = _rank;
        if (_rank != "") then {
            private _displayName = [_rank, "displayName"] call BIS_fnc_rankParams;
            if (_displayName isEqualType "" && {_displayName != ""}) then { _rankName = _displayName };
        };

        #define KEY(suffix) ("STR_antistasi_dialogs_main_playerstats_" + suffix)
        #define STAT(key) (_stats getOrDefault [key, 0])

        // Shots and hits over every weapon and vehicle, for the overall accuracy
        private _weapons = _stats getOrDefault ["weapons", createHashMap];
        private _totalShots = 0;
        private _totalHits = 0;
        {
            if (_y isEqualType []) then {
                _totalShots = _totalShots + (_y param [4, 0, [0]]);
                _totalHits = _totalHits + (_y param [5, 0, [0]]);
            };
        } forEach _weapons;
        private _fnc_accuracy = {
            params ["_shots", "_hits"];
            if (_shots <= 0) then { "-" } else { (str round (100 * _hits / _shots)) + "%" };
        };

        // Row 1: Combat | Activity
        private _combatRows = [
            [KEY("kills_label"), str _kills],
            [KEY("vehicle_kills_label"), str STAT("vehicleKills")],
            [KEY("air_kills_label"), str STAT("airKills")],
            [KEY("civilian_kills_label"), str STAT("civilianKills")],
            [KEY("friendly_kills_label"), str STAT("friendlyKills")],
            [KEY("player_kills_label"), str STAT("playerKills")],
            [KEY("longest_kill_label"), format ["%1 m", STAT("longestKill")]],
            [KEY("deaths_label"), str _deaths],
            [KEY("kd_label"), [_kills, _deaths] call _fnc_formatKD],
            [KEY("shots_fired_label"), str _totalShots],
            [KEY("accuracy_label"), [_totalShots, _totalHits] call _fnc_accuracy, KEY("accuracy_tooltip")]
        ];
        private _activityRows = [
            [KEY("sessions_label"), str STAT("sessions")],
            [KEY("first_seen_label"), [_stats getOrDefault ["firstSeen", []]] call _fnc_formatDate],
            [KEY("last_seen_label"), [_stats getOrDefault ["lastSeen", []]] call _fnc_formatDate],
            [KEY("time_online_label"), [STAT("timeOnline")] call _fnc_formatTime],
            [KEY("longest_session_label"), [STAT("longestSession")] call _fnc_formatTime],
            [KEY("undercover_time_label"), [STAT("undercoverTime")] call _fnc_formatTime]
        ];
        if (_online) then { _activityRows pushBack [KEY("current_session_label"), [_currentSession max 0] call _fnc_formatTime] };

        private _top = 0;
        private _leftBottom = [DETAILS_LEFT, _top, KEY("section_combat"), _combatRows] call _fnc_column;
        private _rightBottom = [DETAILS_RIGHT, _top, KEY("section_activity"), _activityRows] call _fnc_column;
        _top = (_leftBottom max _rightBottom) + DETAILS_SECTION_GAP;

        // Row 2: Medical | Profile
        private _medicalRows = [
            [KEY("times_downed_label"), str STAT("timesDowned")],
            [KEY("revives_label"), str STAT("revives"), KEY("revives_tooltip")]
        ];
        private _profileRows = [
            [KEY("rank_label"), _rankName],
            [KEY("score_label"), _score call _fnc_formatNumber],
            [KEY("missions_label"), _missions call _fnc_formatNumber],
            [KEY("money_label"), [_money] call _fnc_money],
            [KEY("money_earned_label"), [STAT("moneyEarned")] call _fnc_money],
            [KEY("money_spent_label"), [STAT("moneySpent")] call _fnc_money, KEY("money_spent_tooltip")],
            [KEY("money_donated_label"), [STAT("moneyDonated")] call _fnc_money],
            [KEY("scrap_money_label"), [STAT("scrapMoney")] call _fnc_money]
        ];
        _leftBottom = [DETAILS_LEFT, _top, KEY("section_medical"), _medicalRows] call _fnc_column;
        _rightBottom = [DETAILS_RIGHT, _top, KEY("section_profile"), _profileRows] call _fnc_column;
        _top = (_leftBottom max _rightBottom) + DETAILS_SECTION_GAP;

        // Row 3: Operations | Travel and vehicles
        private _operationsRows = [
            [KEY("captures_label"), str STAT("captures"), KEY("captures_tooltip")],
            [KEY("defences_label"), str STAT("defences"), KEY("defences_tooltip")],
            [KEY("intel_found_label"), str STAT("intelFound")],
            [KEY("recruits_lost_label"), str STAT("recruitsLost")],
            [KEY("vehicles_lost_label"), str STAT("vehiclesLost")]
        ];
        private _travelRows = [
            [KEY("vehicles_bought_label"), str STAT("vehiclesBought")],
            [KEY("vehicles_scrapped_label"), str STAT("vehiclesScrapped")],
            [KEY("fast_travels_label"), str STAT("fastTravels")],
            [KEY("flag_teleports_label"), str STAT("flagTeleports")],
            [KEY("air_taxi_rides_label"), str STAT("airTaxiRides")]
        ];
        _leftBottom = [DETAILS_LEFT, _top, KEY("section_operations"), _operationsRows] call _fnc_column;
        _rightBottom = [DETAILS_RIGHT, _top, KEY("section_travel"), _travelRows] call _fnc_column;
        _top = (_leftBottom max _rightBottom) + DETAILS_SECTION_GAP;

        // Row 4: Movement table | Roles table
        private _movement = _stats getOrDefault ["movement", createHashMap];
        private _movementRows = [];
        {
            private _bucket = _movement getOrDefault [_x, [0, 0]];
            if !(_bucket isEqualType [] && {count _bucket >= 2}) then { _bucket = [0, 0] };
            _movementRows pushBack [localize KEY("movement_" + _x), [_bucket select 0] call _fnc_formatTime, [_bucket select 1] call _fnc_formatDistance];
        } forEach ["foot", "ground", "air", "boat", "swim", "static"];
        private _movementColumns = [
            ["STR_antistasi_dialogs_main_towns_name_label", 0, 30, false],
            [KEY("column_time"), 30, 18, true],
            [KEY("column_distance"), 48, 18, true]
        ];

        private _roles = _stats getOrDefault ["roles", createHashMap];
        private _roleNames = ["rifleman", "autorifleman", "grenadier", "medic", "engineer", "teamleader", "commander"];
        { if !(_x in _roleNames) then { _roleNames pushBack _x } } forEach (keys _roles);
        private _roleRows = [];
        {
            private _roleTime = _roles getOrDefault [_x, 0];
            if !(_roleTime isEqualType 0) then { _roleTime = 0 };
            private _roleLabel = localize ("STR_antistasi_dialogs_roleselect_role_" + _x);
            if (_roleLabel == "") then { _roleLabel = _x };
            _roleRows pushBack [_roleLabel, [_roleTime] call _fnc_formatTime];
        } forEach _roleNames;
        private _roleColumns = [
            ["STR_antistasi_dialogs_main_towns_name_label", 0, 40, false],
            [KEY("column_time"), 40, 26, true]
        ];
        _leftBottom = [DETAILS_LEFT, _top, KEY("section_movement"), DETAILS_COLUMN_W, _movementColumns, _movementRows] call _fnc_table;
        _rightBottom = [DETAILS_RIGHT, _top, KEY("section_roles"), DETAILS_COLUMN_W, _roleColumns, _roleRows] call _fnc_table;
        _top = (_leftBottom max _rightBottom) + DETAILS_SECTION_GAP;

        // Row 5: weapons and vehicles, most kills first, then most time
        private _weaponEntries = [];
        {
            private _values = _y;
            if !(_values isEqualType []) then { continue };
            while { count _values < 6 } do { _values pushBack 0 };
            _values params ["_seconds", "_soldiers", "_vehicles", "_aircraft", "_shots", "_hits"];
            _weaponEntries pushBack [_soldiers + _vehicles + _aircraft, _seconds, _x, [_x] call _fnc_weaponName, _seconds, _soldiers, _vehicles, _aircraft, _shots, _hits];
        } forEach _weapons;
        _weaponEntries sort false;
        private _weaponRows = _weaponEntries apply {
            [_x select 3, [_x select 4] call _fnc_formatTime, str (_x select 5), str (_x select 6), str (_x select 7), str (_x select 8), [_x select 8, _x select 9] call _fnc_accuracy]
        };
        private _weaponColumns = [
            [KEY("column_weapon"), 0, 44, false],
            [KEY("column_time"), 44, 16, true],
            [KEY("column_soldiers"), 60, 14, true],
            [KEY("column_vehicles"), 74, 14, true],
            [KEY("column_aircraft"), 88, 14, true],
            [KEY("column_shots"), 102, 16, true],
            [KEY("column_accuracy"), 118, 20, true, KEY("accuracy_tooltip")]
        ];
        _top = [DETAILS_LEFT, _top, KEY("section_weapons"), 138, _weaponColumns, _weaponRows, KEY("no_weapons")] call _fnc_table;

        // Steam UID at the very bottom, admins only, like on the Player Management tab
        if ([] call FUNCMAIN(isLocalAdmin)) then {
            _top = _top + DETAILS_SECTION_GAP;
            ["A3A_Text", DETAILS_LEFT, _top, DETAILS_LABEL_W, localize "STR_antistasi_dialogs_main_admin_player_uid_label"] call _fnc_add;
            ["A3A_TextRight", DETAILS_LEFT + DETAILS_LABEL_W, _top, 138 - DETAILS_LABEL_W, _uid] call _fnc_add;
        };
    };

    default
    {
        // Log error if attempting to call a mode that doesn't exist
        Error_1("Players tab mode does not exist: %1", _mode);
    };
};
