/*
Maintainer: Shoter
    Handles updating, sorting and controls on the Garrisons tab of the Main dialog.
    Lists every rebel-held site (HQ, airbases, outposts, seaports, factories, resources, roadblocks and watchposts)
    with troops, vehicles, statics, static ammo and spawn/attack status. Commander only, the tab button is disabled for everyone else.
    The Resupply button sends a garaged ammo truck, picked in the combo box, to rearm the selected site (fn_garrisonResupplyRequest).

    Troops are read from the "Dum" marker text broadcast by the server (see fn_mrkUpdate), the HQ has no such marker.
    Vehicle, static and ammo counts are requested from the server (fn_garrisonServer_sendCounts) and cached for 30 seconds,
    the ammo truck list (fn_garrisonResupplyListTrucks) is refreshed with them.

Arguments:
    <STRING> Mode
    <ARRAY<ANY>> Array of params for the mode when applicable. Params for specific modes are documented in the modes.

Return Value:
    Nothing

Scope: Clients, Local Arguments, Local Effect
Environment: Unscheduled
Public: No
Dependencies:
    <ARRAY> airportsX, outposts, seaports, factories, resourcesX, outpostsFIA, citiesX, destroyedSites
    <OBJECT> sidesX, spawner

Example:
    ["update"] call FUNC(garrisonsTab);
    ["sortBy", [2]] call FUNC(garrisonsTab); // sort by the Troops column
    ["showOnMap"] call FUNC(garrisonsTab);
    ["manage"] call FUNC(garrisonsTab);

License: APL-ND

*/

#include "..\..\dialogues\ids.inc"
#include "..\..\dialogues\defines.hpp"
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

// Seconds before the vehicle and static counts are requested from the server again
#define COUNTS_CACHE_LIFETIME 30
// Seconds before an unanswered request may be repeated
#define COUNTS_REQUEST_TIMEOUT 5
// Seconds between colour toggles of the rows under attack
#define BLINK_INTERVAL 0.5
#define COLUMN_COUNT 8
// Column index of the static ammo percentage, coloured on its own when low
#define AMMO_COLUMN 5
// Static ammo below this fraction is shown in the understrength colour
#define AMMO_LOW_PCT 50

params [["_mode","onLoad"], ["_params",[]]];

private _display = findDisplay A3A_IDD_MAINDIALOG;
private _tab = _display displayCtrl A3A_IDC_GARRISONSTAB;
private _listBox = _display displayCtrl A3A_IDC_GARRISONSLIST;

// Column index -> [header button IDC, header stringtable key]
private _columns = [
    [A3A_IDC_GARRISONSHEADER_NAME, "STR_antistasi_dialogs_main_towns_name_label"],
    [A3A_IDC_GARRISONSHEADER_TYPE, "STR_antistasi_dialogs_main_garrisons_type_label"],
    [A3A_IDC_GARRISONSHEADER_TROOPS, "STR_antistasi_dialogs_main_garrisons_troops_label"],
    [A3A_IDC_GARRISONSHEADER_VEHICLES, "STR_antistasi_dialogs_main_garrisons_vehicles_label"],
    [A3A_IDC_GARRISONSHEADER_STATICS, "STR_antistasi_dialogs_main_garrisons_statics_label"],
    [A3A_IDC_GARRISONSHEADER_AMMO, "STR_antistasi_dialogs_main_garrisons_ammo_label"],
    [A3A_IDC_GARRISONSHEADER_STATUS, "STR_antistasi_dialogs_main_garrisons_status_label"],
    [A3A_IDC_GARRISONSHEADER_GRID, "STR_antistasi_dialogs_main_towns_grid_label"]
];

// Colours every cell of a row
private _fnc_setRowColor = {
    params ["_listBox", "_row", "_color"];
    for "_column" from 0 to (COLUMN_COUNT - 1) do {
        _listBox lnbSetColor [[_row, _column], _color];
    };
};

switch (_mode) do
{
    case ("update"):
    {
        Trace("Updating Garrisons tab");
        if (isNull _display) exitWith {};

        private _sortColumn = _tab getVariable ["sortColumn", 0];
        private _sortAscending = _tab getVariable ["sortAscending", true];

        // Vehicle and static counts live on the server. Ask for them when the cache is stale,
        // the reply lands in "countsReceived" and runs this update again.
        private _counts = missionNamespace getVariable ["A3A_GUI_garrisonCounts", createHashMap];
        private _countsAge = time - (missionNamespace getVariable ["A3A_GUI_garrisonCountsTime", -1000000]);
        private _requestAge = time - (missionNamespace getVariable ["A3A_GUI_garrisonCountsRequestTime", -1000000]);
        if (_countsAge > COUNTS_CACHE_LIFETIME && {_requestAge > COUNTS_REQUEST_TIMEOUT}) then {
            missionNamespace setVariable ["A3A_GUI_garrisonCountsRequestTime", time];
            [clientOwner] remoteExecCall ["A3A_fnc_garrisonServer_sendCounts", 2];
        };

        // The ammo trucks for the Resupply combo box are fetched with the counts, the reply lands in "trucksReceived"
        private _trucksRequestAge = time - (missionNamespace getVariable ["A3A_GUI_resupplyTrucksRequestTime", -1000000]);
        if (_countsAge > COUNTS_CACHE_LIFETIME && {_trucksRequestAge > COUNTS_REQUEST_TIMEOUT}) then {
            missionNamespace setVariable ["A3A_GUI_resupplyTrucksRequestTime", time];
            ["requestTrucks"] call FUNC(garrisonsTab);
        };

        private _typeLabelHM = createHashMapFromArray [
            ["hq", localize "STR_antistasi_dialogs_main_garrisons_type_hq"],
            ["airbase", localize "STR_antistasi_dialogs_main_garrisons_type_airbase"],
            ["outpost", localize "STR_antistasi_dialogs_main_garrisons_type_outpost"],
            ["seaport", localize "STR_antistasi_dialogs_main_garrisons_type_seaport"],
            ["factory", localize "STR_antistasi_dialogs_main_garrisons_type_factory"],
            ["resource", localize "STR_antistasi_dialogs_main_garrisons_type_resource"],
            ["roadblock", localize "STR_antistasi_dialogs_main_garrisons_type_roadblock"],
            ["watchpost", localize "STR_antistasi_dialogs_main_garrisons_type_watchpost"]
        ];

        // [sort rank, label]. The rank is the sort key so the ordering does not depend on the language
        private _statusUnderAttack = [0, localize "STR_antistasi_dialogs_main_garrisons_status_under_attack"];
        private _statusResupplying = [1, localize "STR_antistasi_dialogs_main_garrisons_status_resupplying"];
        private _statusSpawned = [2, localize "STR_antistasi_dialogs_main_garrisons_status_spawned"];
        private _statusIdle = [3, localize "STR_antistasi_dialogs_main_garrisons_status_idle"];
        private _statusDestroyed = [4, localize "STR_antistasi_dialogs_main_towns_destroyed"];

        private _colorDefault = [1, 1, 1, 1];
        private _colorUnderStrength = A3A_COLOR_UNDERSTRENGTH_SQF;
        private _colorDestroyed = A3A_COLOR_TEXT_DARKER_SQF;

        // Every site that can hold a rebel garrison, HQ is always ours
        private _sites = (airportsX + outposts + seaports + factories + resourcesX + outpostsFIA) select {
            sidesX getVariable [_x, sideUnknown] == teamPlayer
        };
        _sites pushBack "Synd_HQ";

        // One record per site: [sortKey, tieBreaker, marker], display data is looked up by marker
        private _rows = [];
        private _rowData = createHashMap;
        {
            private _marker = _x;
            private _type = [_marker] call FUNC(getLocationMarkerType);
            private _typeLabel = _typeLabelHM getOrDefault [_type, _type];

            // Sites have no name of their own, use the nearest town
            private _name = if (citiesX isEqualTo []) then { _marker } else { [citiesX, markerPos _marker] call BIS_fnc_nearestPosition };
            private _grid = mapGridPosition markerPos _marker;
            private _limit = [_marker] call A3A_fnc_getGarrisonLimit;

            (_counts getOrDefault [_marker, [-1, -1, -1, -1, false]]) params ["_cachedTroops", "_vehicles", "_statics", "_ammoPct", "_resupplying"];

            // Troops come from the "Dum" marker text, "<label>: troops/limit" or no suffix at all when empty.
            // HQ has no such marker so it uses the cached server count instead.
            private _troops = _cachedTroops;
            if (_marker != "Synd_HQ") then {
                private _markerInfo = markerText format ["Dum%1", _marker];
                private _separator = _markerInfo find ":";
                _troops = if (_separator == -1) then { 0 } else {
                    parseNumber (((trim (_markerInfo select [_separator + 1])) splitString "/") select 0)
                };
            };
            private _troopsText = call {
                if (_troops < 0) exitWith { "?" };
                if (_limit == -1) exitWith { str _troops };
                format ["%1/%2", _troops, _limit]
            };
            private _underStrength = _limit > 0 && {_troops >= 0} && {_troops < _limit * 0.5};

            private _underAttack = [markerPos _marker] call A3A_fnc_enemyNearCheck;
            private _status = call {
                if (_underAttack) exitWith { _statusUnderAttack };
                if (_marker in destroyedSites) exitWith { _statusDestroyed };
                if (_resupplying) exitWith { _statusResupplying };
                if (spawner getVariable [_marker, 2] != 2) exitWith { _statusSpawned };
                _statusIdle
            };
            _status params ["_statusRank", "_statusLabel"];

            private _color = call {
                if (_marker in destroyedSites) exitWith { _colorDestroyed };
                if (_underStrength) exitWith { _colorUnderStrength };
                _colorDefault
            };

            private _vehiclesText = [str _vehicles, "?"] select (_vehicles < 0);
            private _staticsText = [str _statics, "?"] select (_statics < 0);
            // Static ammo: unknown until the counts arrive, "-" for sites without statics
            private _ammoText = call {
                if (_statics < 0) exitWith { "?" };
                if (_ammoPct < 0) exitWith { "-" };
                format ["%1%2", _ammoPct, "%"]
            };
            private _ammoLow = _ammoPct >= 0 && {_ammoPct < AMMO_LOW_PCT};
            private _displayStrings = [_name, _typeLabel, _troopsText, _vehiclesText, _staticsText, _ammoText, _statusLabel, _grid];
            private _sortKeys = [toLower _name, _typeLabel, _troops, _vehicles, _statics, _ammoPct, _statusRank, _grid];

            _rows pushBack [_sortKeys select _sortColumn, toLower _name, _marker];
            _rowData set [_marker, [_displayStrings, _color, _underAttack, _ammoLow, _resupplying]];
        } forEach _sites;

        // Keys are homogeneous per column (strings for name/type/grid, numbers for the rest),
        // the lower-cased name and then the unique marker break ties.
        _rows sort _sortAscending;

        // Keep the selection across refreshes (counts arriving, re-sorting)
        private _selectedRow = lnbCurSelRow _listBox;
        private _selectedMarker = if (_selectedRow < 0) then { "" } else { _listBox lnbData [_selectedRow, 0] };

        lbClear _listBox;
        private _attackRows = [];
        {
            _x params ["", "", "_marker"];
            (_rowData get _marker) params ["_displayStrings", "_color", "_underAttack", "_ammoLow", "_resupplying"];
            private _index = _listBox lnbAddRow _displayStrings;
            _listBox lnbSetData [[_index, 0], _marker];
            _listBox lnbSetValue [[_index, 0], parseNumber _underAttack];
            _listBox lnbSetValue [[_index, 1], parseNumber _resupplying];
            [_listBox, _index, _color] call _fnc_setRowColor;
            if (_ammoLow) then { _listBox lnbSetColor [[_index, AMMO_COLUMN], _colorUnderStrength] };
            if (_underAttack) then { _attackRows pushBack [_index, _color] };
            if (_marker == _selectedMarker) then { _listBox lnbSetCurSelRow _index };
        } forEach _rows;

        // Header captions with a sort direction indicator on the active column
        private _arrow = toString [[9660, 9650] select _sortAscending];
        {
            _x params ["_idc", "_key"];
            private _caption = localize _key;
            if (_forEachIndex == _sortColumn) then { _caption = _caption + " " + _arrow };
            (_display displayCtrl _idc) ctrlSetText _caption;
        } forEach _columns;

        // Blink the rows under attack while the tab stays visible. Rows are rebuilt on every update,
        // so the previous loop is stopped before a new one starts with the new row indices.
        terminate (_tab getVariable ["blinkScript", scriptNull]);
        if (_attackRows isNotEqualTo []) then {
            private _blinkScript = [_listBox, _tab, _attackRows, _fnc_setRowColor] spawn {
                params ["_listBox", "_tab", "_attackRows", "_fnc_setRowColor"];
                private _highlight = false;
                while {!isNull _listBox && {ctrlShown _tab}} do {
                    _highlight = !_highlight;
                    {
                        _x params ["_row", "_baseColor"];
                        [_listBox, _row, [_baseColor, A3A_COLOR_UNDER_ATTACK_SQF] select _highlight] call _fnc_setRowColor;
                    } forEach _attackRows;
                    uiSleep BLINK_INTERVAL;
                };
            };
            _tab setVariable ["blinkScript", _blinkScript];
        };

        ["selectionChanged"] call FUNC(garrisonsTab);
    };

    case ("sortBy"):
    {
        // Takes 1 parameter: <NUMBER> column index to sort by. Clicking the active column flips the direction.
        _params params [["_column", 0, [0]]];

        if (_column == (_tab getVariable ["sortColumn", 0])) then {
            _tab setVariable ["sortAscending", !(_tab getVariable ["sortAscending", true])];
        } else {
            _tab setVariable ["sortColumn", _column];
            _tab setVariable ["sortAscending", true];
        };

        ["update"] call FUNC(garrisonsTab);
    };

    case ("selectionChanged"):
    {
        // Manage is blocked while the selected site is under attack, same rule as the HQ dialog
        private _manageButton = _display displayCtrl A3A_IDC_GARRISONSMANAGEBUTTON;
        private _index = lnbCurSelRow _listBox;
        private _underAttack = _index >= 0 && {(_listBox lnbValue [_index, 0]) == 1};
        _manageButton ctrlEnable !_underAttack;
        _manageButton ctrlSetTooltip localize (
            ["STR_antistasi_dialogs_main_garrisons_manage_tooltip", "STR_antistasi_dialogs_hq_garrisons_under_attack"] select _underAttack
        );

        // Resupply needs a site that is not HQ, not under attack, not already being resupplied, and a truck to send
        private _resupplyButton = _display displayCtrl A3A_IDC_GARRISONSRESUPPLYBUTTON;
        private _truckCombo = _display displayCtrl A3A_IDC_GARRISONSRESUPPLYTRUCK;
        private _marker = if (_index < 0) then { "" } else { _listBox lnbData [_index, 0] };
        private _resupplying = _index >= 0 && {(_listBox lnbValue [_index, 1]) == 1};
        private _truckUID = if (lbCurSel _truckCombo < 0) then { -1 } else { _truckCombo lbValue (lbCurSel _truckCombo) };
        private _blocker = call {
            if (_marker isEqualTo "") exitWith { "STR_antistasi_dialogs_main_garrisons_resupply_no_site_tooltip" };
            if (_marker == "Synd_HQ") exitWith { "STR_antistasi_dialogs_main_garrisons_resupply_hq_tooltip" };
            if (_underAttack) exitWith { "STR_antistasi_dialogs_hq_garrisons_under_attack" };
            if (_resupplying) exitWith { "STR_antistasi_dialogs_main_garrisons_resupply_active_tooltip" };
            if (_truckUID < 0) exitWith { "STR_antistasi_dialogs_main_garrisons_resupply_no_truck_tooltip" };
            ""
        };
        _resupplyButton ctrlEnable (_blocker isEqualTo "");
        _resupplyButton ctrlSetTooltip localize ([_blocker, "STR_antistasi_dialogs_main_garrisons_resupply_tooltip"] select (_blocker isEqualTo ""));
    };

    case ("resupply"):
    {
        // Sends the ammo truck picked in the combo box to the selected site, the server validates and answers with hints
        private _index = lnbCurSelRow _listBox;
        if (_index < 0) exitWith {};
        private _marker = _listBox lnbData [_index, 0];
        if (_marker isEqualTo "") exitWith {};
        if (player isNotEqualTo theBoss) exitWith {};

        private _truckCombo = _display displayCtrl A3A_IDC_GARRISONSRESUPPLYTRUCK;
        if (lbCurSel _truckCombo < 0) exitWith {};
        private _truckUID = _truckCombo lbValue (lbCurSel _truckCombo);

        Trace_2("Requesting resupply of %1 with garage truck %2", _marker, _truckUID);
        [player, _marker, _truckUID, clientOwner] remoteExecCall ["A3A_fnc_garrisonResupplyRequest", 2];

        // The status and the truck list change on the server, fetch both again on the next update
        missionNamespace setVariable ["A3A_GUI_garrisonCountsTime", nil];
        ["requestTrucks"] call FUNC(garrisonsTab);
    };

    case ("requestTrucks"):
    {
        // Asks the server for the garaged ammo trucks, the reply lands in "trucksReceived"
        [player, clientOwner] remoteExecCall ["A3A_fnc_garrisonResupplyListTrucks", 2];
    };

    case ("trucksReceived"):
    {
        // Takes 1 parameter: <ARRAY> [[vehUID, displayName, ammoPoints], ...] as sent by A3A_fnc_garrisonResupplyListTrucks
        _params params [["_trucks", [], [[]]]];
        if (isNull _display) exitWith {};

        private _truckCombo = _display displayCtrl A3A_IDC_GARRISONSRESUPPLYTRUCK;
        private _selectedUID = if (lbCurSel _truckCombo < 0) then { -1 } else { _truckCombo lbValue (lbCurSel _truckCombo) };
        lbClear _truckCombo;
        {
            _x params ["_vehUID", "_dispName", "_points"];
            private _row = _truckCombo lbAdd format [localize "STR_antistasi_dialogs_main_garrisons_resupply_truck_entry", _dispName, round _points];
            _truckCombo lbSetValue [_row, _vehUID];
            if (_vehUID == _selectedUID) then { _truckCombo lbSetCurSel _row };
        } forEach _trucks;
        if (lbCurSel _truckCombo < 0 && {lbSize _truckCombo > 0}) then { _truckCombo lbSetCurSel 0 };
        Trace_1("Received %1 ammo trucks for garrison resupply", count _trucks);

        ["selectionChanged"] call FUNC(garrisonsTab);
    };

    case ("showOnMap"):
    {
        private _index = lnbCurSelRow _listBox;
        if (_index < 0) exitWith {};
        private _marker = _listBox lnbData [_index, 0];
        if (_marker isEqualTo "") exitWith {};

        private _position = markerPos _marker;
        closeDialog 0;
        openMap [true, false];
        private _map = (findDisplay 12) displayCtrl 51;
        _map ctrlMapAnimAdd [0, 0.1, _position];
        ctrlMapAnimCommit _map;
    };

    case ("manage"):
    {
        private _index = lnbCurSelRow _listBox;
        if (_index < 0) exitWith {};
        private _marker = _listBox lnbData [_index, 0];
        if (_marker isEqualTo "") exitWith {};
        if (player isNotEqualTo theBoss) exitWith {};

        Trace_1("Opening garrison menu for %1", _marker);
        // The garrison is about to change, drop the cached counts so the next visit fetches fresh ones
        missionNamespace setVariable ["A3A_GUI_garrisonCountsTime", nil];

        // Same flow as the Commander tab garrisons button, the HQ dialog picks the marker up on load
        closeDialog 0;
        player setVariable ["A3A_showGarrisonMenu", true];
        player setVariable ["A3A_garrisonMenuMarker", _marker];
        0 spawn {
            createDialog "A3A_HqDialog";
            uiSleep 1;
            player setVariable ["A3A_showGarrisonMenu", nil];
            player setVariable ["A3A_garrisonMenuMarker", nil];
        };
    };

    case ("countsReceived"):
    {
        // Takes 1 parameter: <ARRAY> [[marker, troops, vehicles, statics, ammoPct, resupplying], ...] as sent by A3A_fnc_garrisonServer_sendCounts
        _params params [["_countsArray", [], [[]]]];

        private _counts = createHashMap;
        {
            _x params ["_marker", "_troops", "_vehicles", "_statics", ["_ammoPct", -1], ["_resupplying", false]];
            _counts set [_marker, [_troops, _vehicles, _statics, _ammoPct, _resupplying]];
        } forEach _countsArray;
        missionNamespace setVariable ["A3A_GUI_garrisonCounts", _counts];
        missionNamespace setVariable ["A3A_GUI_garrisonCountsTime", time];
        Trace_1("Received garrison counts for %1 sites", count _countsArray);

        if (!isNull _display && {ctrlShown _tab}) then {
            ["update"] call FUNC(garrisonsTab);
        };
    };

    default
    {
        // Log error if attempting to call a mode that doesn't exist
        Error_1("Garrisons tab mode does not exist: %1", _mode);
    };
};
