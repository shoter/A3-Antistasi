/*
Maintainer: Shoter
    Handles the Take Over subtab of the Admin tab: the admin picks an enemy site on the shared fast travel map
    and hands it to the rebels, emptied (A3A_fnc_adminTakeOverSite on the server).

Arguments:
    <STRING> Mode
    <ARRAY<ANY>> Array of params for the mode when applicable.

Return Value:
    Nothing

Scope: Clients, Local Arguments, Local Effect
Environment: Unscheduled
Public: No
Dependencies:
    A3A_fnc_adminTakeOverSite

Example:
    ["update"] call FUNC(adminTakeOverTab);

License: APL-ND

*/

#include "..\..\dialogues\ids.inc"
#include "..\..\dialogues\defines.hpp"
#include "..\..\dialogues\textures.inc"
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_mode","update"], ["_params",[]]];

private _display = findDisplay A3A_IDD_MAINDIALOG;
if (isNull _display) exitWith {};
private _map = _display displayCtrl A3A_IDC_FASTTRAVELMAP;
private _selectText = _display displayCtrl A3A_IDC_ADMINTAKEOVERSELECTTEXT;
private _infoText = _display displayCtrl A3A_IDC_ADMINTAKEOVERINFOTEXT;
private _commitButton = _display displayCtrl A3A_IDC_ADMINTAKEOVERCOMMITBUTTON;

// Sites the admin can take over: the ones of the request, no minor sites and no rebel posts
private _fnc_sites = { airportsX + outposts + seaports + factories + resourcesX + citiesX };

switch (_mode) do
{
    case ("update"):
    {
        Trace("Updating admin Take Over tab");
        // Back button returns to the admin tab
        private _backButton = _display displayCtrl A3A_IDC_MAINDIALOGBACKBUTTON;
        _backButton ctrlRemoveAllEventHandlers "MouseButtonClick";
        _backButton ctrlAddEventHandler ["MouseButtonClick", {
            ["switchTab", ["admin"]] call FUNC(mainDialog);
        }];
        _backButton ctrlShow true;

        // Show the shared fast travel map
        _map ctrlShow true;

        private _marker = _map getVariable ["selectedMarker", ""];
        if (_marker isEqualTo "") exitWith {
            _commitButton ctrlEnable false;
            _infoText ctrlShow false;
            _selectText ctrlShow true;
            _selectText ctrlSetText localize "STR_antistasi_dialogs_main_admin_take_over_select";
        };

        private _side = sidesX getVariable [_marker, sideUnknown];
        private _lines = [format [localize "STR_antistasi_dialogs_main_admin_take_over_site", [_marker] call FUNCMAIN(localizar)]];
        private _canCommit = _side in [Occupants, Invaders];
        if (_canCommit) then {
            _lines pushBack format [localize "STR_antistasi_dialogs_main_admin_take_over_owner", Faction(_side) get "name"];
            _lines pushBack localize "STR_antistasi_dialogs_main_admin_take_over_effect";
        } else {
            _lines pushBack localize "STR_antistasi_dialogs_main_admin_take_over_already_rebel";
        };

        _commitButton ctrlEnable _canCommit;
        _selectText ctrlShow false;
        _infoText ctrlShow true;
        _infoText ctrlSetStructuredText parseText (_lines joinString "<br/><br/>");

        // Pan to the site
        _map ctrlMapAnimAdd [0.2, ctrlMapScale _map, markerPos _marker];
        ctrlMapAnimCommit _map;
    };

    case ("mapClicked"):
    {
        // Nearest site to the click, within 8 grid units on screen, as on the Fast Travel tab
        _params params ["_clickedPosition"];
        private _worldPos = _map ctrlMapScreenToWorld _clickedPosition;
        private _marker = [call _fnc_sites, _worldPos] call BIS_fnc_nearestPosition;
        private _markerScreenPos = _map ctrlMapWorldToScreen (markerPos _marker);
        if (_clickedPosition distance _markerScreenPos > 8 * GRID_W) exitWith {
            ["clearSelectedLocation"] call FUNC(adminTakeOverTab);
            ["update"] call FUNC(adminTakeOverTab);
        };

        _map setVariable ["selectedMarker", _marker];
        _map setVariable ["selectMarkerData", [markerPos _marker]];
        ["update"] call FUNC(adminTakeOverTab);
    };

    case ("clearSelectedLocation"):
    {
        _map setVariable ["selectedMarker", ""];
        _map setVariable ["selectMarkerData", []];
    };

    case ("commitButtonClicked"):
    {
        private _marker = _map getVariable ["selectedMarker", ""];
        if (_marker isEqualTo "" || { !((sidesX getVariable [_marker, sideUnknown]) in [Occupants, Invaders]) }) exitWith {};
        ServerInfo_1("Admin takes over %1", _marker);
        [_marker] remoteExecCall ["A3A_fnc_adminTakeOverSite", 2];

        // Stay on the tab for the next site: clear the selection, the map redraws the new owner by itself
        ["clearSelectedLocation"] call FUNC(adminTakeOverTab);
        ["update"] call FUNC(adminTakeOverTab);
    };

    default {
        Error_1("Admin Take Over tab mode does not exist: %1", _mode);
    };
};
