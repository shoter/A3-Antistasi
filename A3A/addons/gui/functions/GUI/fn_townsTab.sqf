/*
Maintainer: Shoter
    Handles updating, sorting and controls on the Towns tab of the Main dialog.

Arguments:
    <STRING> Mode
    <ARRAY<ANY>> Array of params for the mode when applicable. Params for specific modes are documented in the modes.

Return Value:
    Nothing

Scope: Clients, Local Arguments, Local Effect
Environment: Unscheduled
Public: No
Dependencies:
    <ARRAY> citiesX
    <NAMESPACE> A3A_cityData
    <OBJECT> sidesX
    <ARRAY> destroyedSites
    <HASHMAP> A3A_cityInvest, A3A_townUpgradeHM, A3A_townUpgradeOrder

Example:
    ["update"] call FUNC(townsTab);
    ["sortBy", [2]] call FUNC(townsTab); // sort by the Support column
    ["showOnMap"] call FUNC(townsTab);

License: APL-ND

*/

#include "..\..\dialogues\ids.inc"
#include "..\..\dialogues\defines.hpp"
#include "..\..\dialogues\textures.inc"
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_mode","onLoad"], ["_params",[]]];

private _display = findDisplay A3A_IDD_MAINDIALOG;
private _tab = _display displayCtrl A3A_IDC_TOWNSTAB;
private _listBox = _display displayCtrl A3A_IDC_TOWNSLIST;

// Column index -> [header button IDC, header stringtable key]
private _columns = [
    [A3A_IDC_TOWNSHEADER_NAME, "STR_antistasi_dialogs_main_towns_name_label"],
    [A3A_IDC_TOWNSHEADER_OWNER, "STR_antistasi_dialogs_main_towns_owner_label"],
    [A3A_IDC_TOWNSHEADER_SUPPORT, "STR_antistasi_dialogs_main_towns_support_label"],
    [A3A_IDC_TOWNSHEADER_POPULATION, "STR_antistasi_dialogs_main_towns_population_label"],
    [A3A_IDC_TOWNSHEADER_GARRISON, "STR_antistasi_dialogs_main_towns_garrison_label"],
    [A3A_IDC_TOWNSHEADER_UPGRADES, "STR_antistasi_dialogs_main_towns_upgrades_label"],
    [A3A_IDC_TOWNSHEADER_GRID, "STR_antistasi_dialogs_main_towns_grid_label"]
];

private _upgradesReady = !isNil "A3A_townUpgradeHM" && !isNil "A3A_cityInvest";

// Installed upgrade ids of a town in display order
private _fnc_installed = {
    params ["_city"];
    if (!_upgradesReady) exitWith { [] };
    private _installed = keys (A3A_cityInvest getOrDefault [_city, createHashMap]);
    A3A_townUpgradeOrder select { _x in _installed };
};

switch (_mode) do
{
    case ("update"):
    {
        Trace("Updating Towns tab");
        if (isNull _display) exitWith {};

        private _sortColumn = _tab getVariable ["sortColumn", 0];
        private _sortAscending = _tab getVariable ["sortAscending", true];

        // Side colours, same source as the map marker drawing
        private _sideColorHM = createHashMapFromArray [
            [teamPlayer, ["Map", "Independent"] call BIS_fnc_displayColorGet],
            [Occupants, ["Map", "BLUFOR"] call BIS_fnc_displayColorGet],
            [Invaders, ["Map", "OPFOR"] call BIS_fnc_displayColorGet],
            [sideUnknown, ["Map", "Unknown"] call BIS_fnc_displayColorGet]
        ];
        private _colorDestroyed = A3A_COLOR_TEXT_DARKER_SQF;

        private _sideLabelHM = createHashMapFromArray [
            [teamPlayer, localize "STR_antistasi_dialogs_main_warstatus_rebels"],
            [Occupants, localize "STR_antistasi_dialogs_main_warstatus_occupants"],
            [Invaders, localize "STR_antistasi_dialogs_main_warstatus_invaders"]
        ];
        private _labelDestroyed = localize "STR_antistasi_dialogs_main_towns_destroyed";

        // Build one record per town: [sortKey, tieBreaker, displayStrings, color, city]
        private _rows = [];
        {
            private _city = _x;
            private _side = sidesX getVariable [_city, sideUnknown];
            private _destroyed = _city in destroyedSites;
            (A3A_cityData getVariable [_city, [0, 0]]) params ["_numCiv", "_supportReb"];

            private _ownerLabel = if (_destroyed) then { _labelDestroyed } else { _sideLabelHM getOrDefault [_side, ""] };
            private _color = if (_destroyed) then { _colorDestroyed } else { _sideColorHM getOrDefault [_side, _sideColorHM get sideUnknown] };

            // Rebel garrisons are published to clients through the "Dum" marker text as "<label>: troops/limit".
            // Cities have an empty label, so the text is ": troops/limit" or "" when the garrison is empty.
            private _garrisonText = "-";
            private _garrisonCount = -1;
            if (_side == teamPlayer && !_destroyed) then {
                private _markerInfo = markerText format ["Dum%1", _city];
                _garrisonText = trim (_markerInfo select [(_markerInfo find ":") + 1]);
                if (_garrisonText isEqualTo "") then {
                    private _limit = [_city] call A3A_fnc_getGarrisonLimit;
                    _garrisonText = if (_limit == -1) then { "0" } else { format ["0/%1", _limit] };
                };
                _garrisonCount = parseNumber ((_garrisonText splitString "/") select 0);
            };

            // Installed town upgrades as letter codes
            private _installed = [_city] call _fnc_installed;
            private _upgradesText = if (_installed isEqualTo []) then { "-" } else { (_installed apply { (A3A_townUpgradeHM get _x) # 3 }) joinString " " };

            private _grid = mapGridPosition markerPos _city;

            private _displayStrings = [_city, _ownerLabel, (str round _supportReb) + "%", str _numCiv, _garrisonText, _upgradesText, _grid];
            private _sortKeys = [toLower _city, _ownerLabel, _supportReb, _numCiv, _garrisonCount, count _installed, _grid];

            _rows pushBack [_sortKeys select _sortColumn, toLower _city, _displayStrings, _color, _city];
        } forEach citiesX;

        // Keys are homogeneous per column (strings for name/owner/grid, numbers for the rest),
        // the lower-cased name breaks ties so the nested arrays are never compared.
        _rows sort _sortAscending;

        lbClear _listBox;
        {
            _x params ["", "", "_displayStrings", "_color", "_city"];
            private _index = _listBox lnbAddRow _displayStrings;
            _listBox lnbSetData [[_index, 0], _city];
            _listBox lnbSetColor [[_index, 0], _color];
            _listBox lnbSetColor [[_index, 1], _color];
        } forEach _rows;

        // Header captions with a sort direction indicator on the active column
        private _arrow = toString [[9660, 9650] select _sortAscending];
        {
            _x params ["_idc", "_key"];
            private _caption = localize _key;
            if (_forEachIndex == _sortColumn) then { _caption = _caption + " " + _arrow };
            (_display displayCtrl _idc) ctrlSetText _caption;
        } forEach _columns;

        // Selection is gone after the rebuild, show the legend
        ["selectionChanged"] call FUNC(townsTab);
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

        ["update"] call FUNC(townsTab);
    };

    case ("selectionChanged"):
    {
        // Upgrades of the selected town, or the code legend when no row is selected
        private _text = _display displayCtrl A3A_IDC_TOWNSUPGRADESTEXT;
        if (!_upgradesReady) exitWith { _text ctrlSetStructuredText parseText "" };

        private _index = lnbCurSelRow _listBox;
        private _city = if (_index < 0) then { "" } else { _listBox lnbData [_index, 0] };
        private _lines = [];

        if (_city == "") then {
            _lines pushBack format ["<t size='0.8'>%1</t>", localize "STR_antistasi_dialogs_main_towns_upgrades_legend"];
            {
                _lines pushBack format ["%1   %2", (A3A_townUpgradeHM get _x) # 3, localize format ["STR_A3A_fn_townUpgrades_name_%1", _x]];
            } forEach A3A_townUpgradeOrder;
        } else {
            _lines pushBack format ["<t size='0.8'>%1</t>", format [localize "STR_antistasi_dialogs_main_towns_upgrades_title", _city]];
            private _installed = [_city] call _fnc_installed;
            if (_installed isEqualTo []) then {
                _lines pushBack (localize "STR_antistasi_dialogs_main_towns_upgrades_none");
            } else {
                {
                    _lines pushBack format ["%1   %2", (A3A_townUpgradeHM get _x) # 3, localize format ["STR_A3A_fn_townUpgrades_name_%1", _x]];
                } forEach _installed;
            };
        };

        _text ctrlSetStructuredText parseText format ["<t size='0.7'>%1</t>", _lines joinString "<br/>"];
    };

    case ("showOnMap"):
    {
        private _index = lnbCurSelRow _listBox;
        if (_index < 0) exitWith {};
        private _city = _listBox lnbData [_index, 0];
        if (_city isEqualTo "") exitWith {};

        private _position = markerPos _city;
        closeDialog 0;
        openMap [true, false];
        private _map = (findDisplay 12) displayCtrl 51;
        _map ctrlMapAnimAdd [0, 0.1, _position];
        ctrlMapAnimCommit _map;
    };

    default
    {
        // Log error if attempting to call a mode that doesn't exist
        Error_1("Towns tab mode does not exist: %1", _mode);
    };
};
