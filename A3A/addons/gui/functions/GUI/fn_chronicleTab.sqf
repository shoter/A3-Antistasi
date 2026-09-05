/*
Maintainer: Shoter
    Handles the Chronicle tab of the Main dialog: fetches the campaign log delta from the server,
    filters it by category and renders it newest first with relative times and a map jump.

Arguments:
    <STRING> Mode
    <ARRAY<ANY>> Array of params for the mode when applicable. Params for specific modes are documented in the modes.

Return Value:
    Nothing

Scope: Clients, Local Arguments, Local Effect
Environment: Unscheduled
Public: No
Dependencies:
    <NUMBER> A3A_campaignLogVersion
    <NUMBER> A3A_campaignLogCap
    <ARRAY> A3A_campaignLog (only read where this machine is the server)
    A3A_fnc_campaignLogRequest, A3A_fnc_localizar, A3A_fnc_junkyardClock, A3A_fnc_timeSpan_format

Example:
    ["update"] call FUNC(chronicleTab);
    ["filter", ["attacks"]] call FUNC(chronicleTab);
    ["page", [1]] call FUNC(chronicleTab); // one page of older entries
    ["receive", [12, [[12, 3600, "siteCaptured", "outpost_3", ["AAF"], "Shoter"]]]] call FUNC(chronicleTab); // sent by the server
    ["showOnMap"] call FUNC(chronicleTab);

License: APL-ND

*/

#include "..\..\dialogues\ids.inc"
#include "..\..\dialogues\defines.hpp"
#include "..\..\dialogues\textures.inc"
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

#define CHRONICLE_PAGE_SIZE 50

params [["_mode","onLoad"], ["_params",[]]];

private _display = findDisplay A3A_IDD_MAINDIALOG;
private _tab = _display displayCtrl A3A_IDC_CHRONICLETAB;
private _listBox = _display displayCtrl A3A_IDC_CHRONICLELIST;

// Filter id -> button IDC, in strip order
private _filters = [
    ["all", A3A_IDC_CHRONICLEFILTER_ALL],
    ["sites", A3A_IDC_CHRONICLEFILTER_SITES],
    ["towns", A3A_IDC_CHRONICLEFILTER_TOWNS],
    ["attacks", A3A_IDC_CHRONICLEFILTER_ATTACKS],
    ["missions", A3A_IDC_CHRONICLEFILTER_MISSIONS],
    ["hq", A3A_IDC_CHRONICLEFILTER_HQ],
    ["players", A3A_IDC_CHRONICLEFILTER_PLAYERS],
    ["arsenal", A3A_IDC_CHRONICLEFILTER_ARSENAL],
    ["campaign", A3A_IDC_CHRONICLEFILTER_CAMPAIGN]
];

// Event type -> [filter, tone, kinds of the extra params]
// Kinds: "text" as is, "marker" localized site name, "rank" rank display name, "aggro" aggression level name, "item" config display name
// Tones: "good" rebel gain, "bad" rebel loss, "warning" incoming attack, "neutral", "enemy" enemy-vs-enemy
private _types = createHashMapFromArray [
    ["siteCaptured",         ["sites",    "good",    ["text"]]],
    ["siteLost",             ["sites",    "bad",     ["text"]]],
    ["siteChangedHands",     ["sites",    "enemy",   ["text", "text"]]],
    ["townCaptured",         ["towns",    "good",    ["text"]]],
    ["townLost",             ["towns",    "bad",     ["text"]]],
    ["townChanged",          ["towns",    "enemy",   ["text", "text"]]],
    ["townDestroyed",        ["towns",    "bad",     ["text"]]],
    ["attackStarted",        ["attacks",  "warning", ["text", "marker"]]],
    ["counterattackStarted", ["attacks",  "warning", ["text", "marker"]]],
    ["attackRepelled",       ["attacks",  "good",    ["text"]]],
    ["enemyAttackStarted",   ["attacks",  "enemy",   ["text", "text", "marker"]]],
    ["punishmentStarted",    ["attacks",  "warning", ["text", "marker"]]],
    ["punishmentRepelled",   ["attacks",  "good",    ["text"]]],
    ["hqAttacked",           ["hq",       "warning", ["text", "marker"]]],
    ["hqDefended",           ["hq",       "good",    ["text"]]],
    ["petrosKilled",         ["hq",       "bad",     ["text"]]],
    ["hqMoved",              ["hq",       "neutral", []]],
    ["playerPromoted",       ["players",  "good",    ["rank"]]],
    ["warLevelChanged",      ["campaign", "neutral", ["text", "text"]]],
    ["campaignWon",          ["campaign", "good",    []]],
    ["campaignLost",         ["campaign", "bad",     []]],
    ["missionSucceeded",     ["missions", "good",    ["text"]]],
    ["missionFailed",        ["missions", "bad",     ["text"]]],
    ["commanderAssigned",    ["players",  "neutral", []]],
    ["commanderChanged",     ["players",  "neutral", ["text"]]],
    ["campaignStarted",      ["campaign", "neutral", ["text", "text", "text", "text"]]],
    ["radioTowerDestroyed",  ["sites",    "good",    []]],
    ["radioTowerRebuilt",    ["sites",    "good",    []]],
    ["aggressionChanged",    ["campaign", "neutral", ["text", "aggro", "aggro"]]],
    ["populationMajority",   ["campaign", "good",    []]],
    ["populationMajorityLost", ["campaign", "bad",   []]],
    ["rewardSplitChanged",   ["players",  "neutral", ["text", "text"]]],
    ["itemUnlocked",         ["arsenal",  "good",    ["item"]]]
];

// The server reads its own log, everyone else keeps the copy filled by "receive"
private _fnc_entries = {
    if (isServer) exitWith { A3A_campaignLog };
    missionNamespace getVariable ["A3A_chronicleLog", []]
};

switch (_mode) do
{
    case ("update"):
    {
        Trace("Updating Chronicle tab");
        if (isNull _display) exitWith {};

        // Ask the server for the entries we have not seen yet, the reply re-renders through "receive"
        private _loading = false;
        if (!isServer) then {
            private _knownSeq = missionNamespace getVariable ["A3A_chronicleSeq", 0];
            if (_knownSeq != A3A_campaignLogVersion) then {
                _loading = true;
                [clientOwner, _knownSeq] remoteExecCall [QFUNCMAIN(campaignLogRequest), 2];
            };
        };

        ["render", [_loading]] call FUNC(chronicleTab);
    };

    case ("render"):
    {
        // Takes 1 optional parameter: <BOOL> whether a delta was just requested from the server
        _params params [["_loading", false, [false]]];
        if (isNull _display) exitWith {};

        private _filter = _tab getVariable ["filter", "all"];
        private _entries = call _fnc_entries;
        private _now = call A3A_fnc_junkyardClock;

        private _toneColorHM = createHashMapFromArray [
            ["good", ["Map", "Independent"] call BIS_fnc_displayColorGet],
            ["bad", ["Map", "OPFOR"] call BIS_fnc_displayColorGet],
            ["warning", [1, 0.85, 0.4, 1]],
            ["neutral", [1, 1, 1, 1]],
            ["enemy", A3A_COLOR_TEXT_DARKER_SQF]
        ];
        private _noActor = localize "STR_antistasi_dialogs_main_chronicle_no_actor";
        private _agoFormat = localize "STR_antistasi_dialogs_main_chronicle_ago";
        private _justNow = localize "STR_antistasi_dialogs_main_chronicle_just_now";

        lbClear _listBox;
        private _shown = 0;

        // Entries that pass the filter, newest first, then only the current page of them
        private _visible = [];
        for "_i" from (count _entries - 1) to 0 step -1 do {
            private _category = (_types getOrDefault [(_entries select _i) select 2, ["campaign", "neutral", []]]) select 0;
            if (_filter == "all" || {_filter == _category}) then { _visible pushBack _i };
        };
        private _pageCount = (ceil ((count _visible) / CHRONICLE_PAGE_SIZE)) max 1;
        private _page = ((_tab getVariable ["page", 0]) min (_pageCount - 1)) max 0;
        _tab setVariable ["page", _page];

        {
            private _i = _x;
            (_entries select _i) params ["", "_time", "_type", "_target", "_eventParams", "_actor"];
            (_types getOrDefault [_type, ["campaign", "neutral", []]]) params ["", "_tone", "_kinds"];

            // Text is "%1 target, %2 actor, %3.. params", all localized here rather than on the server
            private _targetName = call {
                if (_target isEqualType []) exitWith { mapGridPosition _target };
                if (_target isEqualTo "") exitWith { "" };
                [_target] call A3A_fnc_localizar
            };
            if (_actor isEqualTo "") then { _actor = _noActor };
            private _formatParams = [localize (format ["STR_antistasi_dialogs_main_chronicle_ev_%1", _type]), _targetName, _actor];
            {
                private _kind = _kinds param [_forEachIndex, "text"];
                private _value = _x;
                _formatParams pushBack (call {
                    if (_kind == "marker") exitWith { [_value] call A3A_fnc_localizar };
                    if (_kind == "rank") exitWith { [_value, "displayName"] call BIS_fnc_rankParams };
                    if (_kind == "aggro") exitWith { format ["%1 (%2)", _value, [_value] call A3A_fnc_getAggroLevelString] };
                    if (_kind == "item") exitWith {
                        private _cfg = [configFile >> "CfgWeapons", configFile >> "CfgVehicles", configFile >> "CfgGlasses", configFile >> "CfgMagazines"] select { isClass (_x >> _value) };
                        private _name = if (_cfg isEqualTo []) then { "" } else { getText ((_cfg select 0) >> _value >> "displayName") };
                        if (_name isEqualTo "") then { _value } else { _name }
                    };
                    _value
                });
            } forEach _eventParams;
            private _text = format _formatParams;

            private _secs = (_now - _time) max 0;
            private _ago = if (_secs < 60) then { _justNow } else {
                format [_agoFormat, [_secs, 1, 0, false, 2, false, true] call A3A_fnc_timeSpan_format]
            };

            private _index = _listBox lnbAddRow [_ago, _text];
            _listBox lnbSetValue [[_index, 0], _i];
            _listBox lnbSetTooltip [[_index, 1], _text];
            private _color = _toneColorHM get _tone;
            _listBox lnbSetColor [[_index, 0], _color];
            _listBox lnbSetColor [[_index, 1], _color];
            _shown = _shown + 1;
        } forEach (_visible select [_page * CHRONICLE_PAGE_SIZE, CHRONICLE_PAGE_SIZE]);

        if (_shown == 0) then {
            private _key = ["STR_antistasi_dialogs_main_chronicle_empty", "STR_antistasi_dialogs_main_chronicle_loading"] select _loading;
            private _index = _listBox lnbAddRow ["", localize _key];
            _listBox lnbSetValue [[_index, 0], -1];
            _listBox lnbSetColor [[_index, 1], A3A_COLOR_TEXT_DARKER_SQF];
        };

        // The active filter is drawn in bright text, the rest darker
        {
            _x params ["_id", "_idc"];
            (_display displayCtrl _idc) ctrlSetTextColor ([A3A_COLOR_TEXT_DARKER_SQF, [1, 1, 1, 1]] select (_id == _filter));
        } forEach _filters;

        (_display displayCtrl A3A_IDC_CHRONICLENEWERPAGEBUTTON) ctrlEnable (_page > 0);
        (_display displayCtrl A3A_IDC_CHRONICLEOLDERPAGEBUTTON) ctrlEnable (_page < _pageCount - 1);
        (_display displayCtrl A3A_IDC_CHRONICLEPAGELABEL) ctrlSetText format [localize "STR_antistasi_dialogs_main_chronicle_page", _page + 1, _pageCount];
    };

    case ("filter"):
    {
        // Takes 1 parameter: <STRING> filter id, one of the ids in _filters. Starts again from the newest entries.
        _params params [["_filter", "all", [""]]];
        _tab setVariable ["filter", _filter];
        _tab setVariable ["page", 0];
        ["render"] call FUNC(chronicleTab);
    };

    case ("page"):
    {
        // Takes 1 parameter: <NUMBER> pages to move by, positive towards older entries. "render" clamps the result.
        _params params [["_delta", 0, [0]]];
        _tab setVariable ["page", (_tab getVariable ["page", 0]) + _delta];
        ["render"] call FUNC(chronicleTab);
    };

    case ("receive"):
    {
        // Sent by A3A_fnc_campaignLogRequest. Takes 2 parameters:
        // <NUMBER> sequence number of the newest entry on the server, <ARRAY> entries newer than the ones we asked with
        _params params [["_seq", 0, [0]], ["_entries", [], [[]]]];

        private _knownSeq = missionNamespace getVariable ["A3A_chronicleSeq", 0];
        private _log = missionNamespace getVariable ["A3A_chronicleLog", []];
        _log append (_entries select { (_x select 0) > _knownSeq });      // a repeated request must not duplicate rows
        if (count _log > A3A_campaignLogCap) then { _log deleteRange [0, count _log - A3A_campaignLogCap] };
        A3A_chronicleLog = _log;
        A3A_chronicleSeq = _seq max _knownSeq;
        Debug_2("Received %1 chronicle entries, now at #%2", count _entries, A3A_chronicleSeq);

        if (isNull _display) exitWith {};
        if (ctrlShown _tab) then { ["render"] call FUNC(chronicleTab) };
    };

    case ("showOnMap"):
    {
        private _row = lnbCurSelRow _listBox;
        if (_row < 0) exitWith {};
        private _index = _listBox lnbValue [_row, 0];
        private _entries = call _fnc_entries;
        if (_index < 0 || {_index >= count _entries}) exitWith {};

        private _target = (_entries select _index) select 3;
        private _position = call {
            if (_target isEqualType []) exitWith { _target };
            if (_target isEqualTo "" || {markerShape _target isEqualTo ""}) exitWith { [] };
            markerPos _target
        };
        if (_position isEqualTo []) exitWith {};

        closeDialog 0;
        openMap [true, false];
        private _map = (findDisplay 12) displayCtrl 51;
        _map ctrlMapAnimAdd [0, 0.1, _position];
        ctrlMapAnimCommit _map;
    };

    default
    {
        // Log error if attempting to call a mode that doesn't exist
        Error_1("Chronicle tab mode does not exist: %1", _mode);
    };
};
