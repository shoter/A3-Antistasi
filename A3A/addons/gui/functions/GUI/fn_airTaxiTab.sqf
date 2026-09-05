/*
Maintainer: Shoter
    Handles updating and controls on the Air Taxi tab of the Main dialog.
    The player picks a garaged helicopter from the list and a destination on the shared fast travel map,
    sees the fare, the pilot's HR, seats and blockers, and requests the pickup from the server.

Arguments:
    <STRING> Mode
    <ARRAY<ANY>> Array of params for the mode when applicable. Params for specific modes are documented in the modes.

Return Value:
    Nothing

Scope: Clients, Local Arguments, Local Effect
Environment: Unscheduled
Public: No
Dependencies:
    A3A_fnc_airTaxiCanRequest, A3A_fnc_airTaxiFare, A3A_fnc_airTaxiListHelis (server reply "receiveHelis")

Example:
    ["update"] call FUNC(airTaxiTab);
    ["receiveHelis", [_helis]] remoteExecCall ["A3A_GUI_fnc_airTaxiTab", _client];  // from the server

License: APL-ND

*/

#include "..\..\dialogues\ids.inc"
#include "..\..\dialogues\defines.hpp"
#include "..\..\dialogues\textures.inc"
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_mode","update"], ["_params",[]]];

private _display = findDisplay A3A_IDD_MAINDIALOG;
if (isNull _display) exitWith {};       // dialog closed, e.g. before the server replied with the heli list
private _tab = _display displayCtrl A3A_IDC_AIRTAXITAB;
private _map = _display displayCtrl A3A_IDC_FASTTRAVELMAP;
private _heliList = _display displayCtrl A3A_IDC_AIRTAXIHELILIST;
private _infoText = _display displayCtrl A3A_IDC_AIRTAXIINFOTEXT;
private _commitButton = _display displayCtrl A3A_IDC_AIRTAXICOMMITBUTTON;

switch (_mode) do
{
    case ("update"):
    {
        Trace("Updating Air Taxi tab");
        // Show back button
        private _backButton = _display displayCtrl A3A_IDC_MAINDIALOGBACKBUTTON;
        _backButton ctrlRemoveAllEventHandlers "MouseButtonClick";
        _backButton ctrlAddEventHandler ["MouseButtonClick", {
            ["switchTab", ["player"]] call FUNC(mainDialog);
        }];
        _backButton ctrlShow true;

        // Show the shared fast travel map
        _map ctrlShow true;

        // Ask the server for the helicopters once
        private _helis = _tab getVariable "heliList";       // nil until received, [] when none
        if (isNil "_helis" && { !(_tab getVariable ["heliListPending", false]) }) exitWith {
            ["requestHelis"] call FUNC(airTaxiTab);
        };

        private _heliUID = _tab getVariable ["selectedHeliUID", -1];
        private _marker = _map getVariable ["selectedMarker", ""];
        private _lines = [];
        private _canCommit = true;

        // Helicopter
        private _class = "";
        if (isNil "_helis") then {
            _lines pushBack localize "STR_antistasi_dialogs_main_air_taxi_loading";
            _canCommit = false;
        } else {
            private _index = _helis findIf { _x # 0 == _heliUID };
            switch (true) do {
                case (_helis isEqualTo []): { _lines pushBack localize "STR_antistasi_dialogs_main_air_taxi_no_helis"; _canCommit = false };
                case (_index == -1): { _lines pushBack localize "STR_antistasi_dialogs_main_air_taxi_select_heli"; _canCommit = false };
                default {
                    _class = _helis # _index # 1;
                    _lines pushBack format [localize "STR_antistasi_dialogs_main_air_taxi_helicopter", _helis # _index # 2];
                };
            };
        };

        // Destination
        if (_marker == "") then {
            _lines pushBack localize "STR_antistasi_dialogs_main_air_taxi_select_location";
            _canCommit = false;
        } else {
            private _locationName = [_marker] call FUNC(getLocationMarkerName);
            _lines pushBack format [localize "STR_antistasi_dialogs_main_air_taxi_destination", _locationName, mapGridPosition markerPos _marker];
            private _distanceKm = (round ((getPosATL player distance2D markerPos _marker) / 100)) / 10;
            _lines pushBack format [localize "STR_antistasi_dialogs_main_air_taxi_distance", _distanceKm];
        };

        // Fare, time and seats once both are chosen
        if (_marker != "" && _class != "") then {
            ([getPosATL player, markerPos _marker, _class] call FUNCMAIN(airTaxiFare)) params ["_money", "_hr", "", "_eta"];
            private _etaString = [[_eta] call FUNCMAIN(secondsToTimeSpan), 0, 0, false, 2] call FUNCMAIN(timeSpan_format);
            _lines pushBack format [localize "STR_antistasi_dialogs_main_air_taxi_eta", _etaString];
            _lines pushBack format [localize "STR_antistasi_dialogs_main_air_taxi_fare", _money, _hr];

            // Same pickup rule as fast travel: the leader brings squad AI within 50 m
            private _isLeader = player == leader group player;
            private _passengers = if (_isLeader) then {
                count ((units group player inAreaArray [getPosATL player, 50, 50]) select { !isPlayer _x }) + 1
            } else { 1 };
            private _seats = ([_class, true] call BIS_fnc_crewCount) - ([_class, false] call BIS_fnc_crewCount);
            _lines pushBack format [localize "STR_antistasi_dialogs_main_air_taxi_seats", _passengers, _seats];
            if (_passengers > _seats) then { _lines pushBack format [localize "STR_antistasi_dialogs_main_air_taxi_seats_warning", _seats] };
            if (_isLeader) then { _lines pushBack localize "STR_antistasi_dialogs_main_air_taxi_pickup_squad" };

            if (player getVariable ["moneyX", 0] < _money) then {
                _lines pushBack format [localize "STR_A3A_fn_logistics_airTaxi_blk_no_money", _money];
                _canCommit = false;
            };
            if (server getVariable ["hr", 0] < _hr) then {
                _lines pushBack localize "STR_A3A_fn_logistics_airTaxi_blk_no_hr";
                _canCommit = false;
            };
        };

        // Blockers
        private _blockers = if (_marker == "") then {
            [player] call FUNCMAIN(airTaxiCanRequest)
        } else {
            [player, _marker] call FUNCMAIN(airTaxiCanRequest)
        };
        if (_blockers isNotEqualTo []) then {
            _canCommit = false;
            _lines append (_blockers apply { localize ("STR_A3A_fn_logistics_airTaxi_blk_" + _x) });
        };

        _infoText ctrlSetStructuredText parseText (_lines joinString "<br/><br/>");
        _commitButton ctrlEnable _canCommit;

        // Pan to location
        if (_marker != "") then {
            _map ctrlMapAnimAdd [0.2, ctrlMapScale _map, markerPos _marker];
            ctrlMapAnimCommit _map;
        };
    };

    case ("requestHelis"):
    {
        _tab setVariable ["heliListPending", true];
        lbClear _heliList;
        [player, clientOwner] remoteExecCall ["A3A_fnc_airTaxiListHelis", 2];
        ["update"] call FUNC(airTaxiTab);
    };

    case ("receiveHelis"):
    {
        // Takes 1 parameter: <ARRAY> list of [vehUID, class, displayName, lockedByOther] from the server
        _params params [["_helis", [], [[]]]];
        Debug_1("Air taxi helis received: %1", count _helis);
        _tab setVariable ["heliList", _helis];
        _tab setVariable ["heliListPending", false];

        lbClear _heliList;
        {
            _x params ["_uid", "_class", "_dispName", "_lockedByOther"];
            private _index = _heliList lbAdd _dispName;
            _heliList lbSetValue [_index, _uid];
            _heliList lbSetPicture [_index, getText (configFile >> "CfgVehicles" >> _class >> "picture")];
            if (_lockedByOther) then {
                _heliList lbSetColor [_index, [1, 1, 1, 0.4]];
                _heliList lbSetPictureColor [_index, [1, 1, 1, 0.4]];
                _heliList lbSetTooltip [_index, localize "STR_antistasi_dialogs_main_air_taxi_locked_tooltip"];
            };
        } forEach _helis;
        lbSort _heliList;
        _heliList ctrlEnable (_helis isNotEqualTo []);

        // Keep the previous selection if it still exists
        private _selectedUID = _tab getVariable ["selectedHeliUID", -1];
        private _selected = -1;
        for "_i" from 0 to (lbSize _heliList) - 1 do {
            if (_heliList lbValue _i == _selectedUID) exitWith { _selected = _i };
        };
        if (_selected == -1) then { _tab setVariable ["selectedHeliUID", -1] };
        _heliList lbSetCurSel _selected;        // fires heliSelected, which updates the tab

        ["update"] call FUNC(airTaxiTab);
    };

    case ("heliSelected"):
    {
        private _index = lbCurSel _heliList;
        private _uid = -1;
        if (_index != -1) then {
            _uid = _heliList lbValue _index;
            private _helis = _tab getVariable ["heliList", []];
            private _entryIndex = _helis findIf { _x # 0 == _uid };
            if (_entryIndex != -1 && { _helis # _entryIndex # 3 }) then {
                // Locked by another player, not selectable
                _uid = -1;
                _heliList lbSetCurSel -1;
            };
        };
        _tab setVariable ["selectedHeliUID", _uid];
        ["update"] call FUNC(airTaxiTab);
    };

    case ("mapClicked"):
    {
        // Same location picking as the fast travel tab, without a side filter: any marker is a valid destination
        Debug_1("Air Taxi map clicked: %1", _params);
        _params params ["_clickedPosition"];
        private _clickedWorldPosition = _map ctrlMapScreenToWorld _clickedPosition;
        private _locations = airportsX + resourcesX + factories + outposts + seaports + citiesX + outpostsFIA + ["Synd_HQ"];
        private _selectedMarker = [_locations, _clickedWorldPosition] call BIS_fnc_nearestPosition;

        private _markerMapPosition = _map ctrlMapWorldToScreen (getMarkerPos _selectedMarker);
        private _maxDistance = 8 * GRID_W;
        if (_clickedPosition distance _markerMapPosition > _maxDistance) exitWith {
            ["clearSelectedLocation"] call FUNC(airTaxiTab);
            ["update"] call FUNC(airTaxiTab);
        };

        _map setVariable ["selectedMarker", _selectedMarker];
        _map setVariable ["selectMarkerData", [getMarkerPos _selectedMarker]];
        ["update"] call FUNC(airTaxiTab);
    };

    case ("clearSelectedLocation"):
    {
        _map setVariable ["selectedMarker", ""];
        _map setVariable ["selectMarkerData", []];
    };

    case ("commitButtonClicked"):
    {
        private _uid = _tab getVariable ["selectedHeliUID", -1];
        private _marker = _map getVariable ["selectedMarker", ""];
        if (_uid == -1 || _marker == "") exitWith {};
        closeDialog 1;
        [player, _uid, _marker, clientOwner] remoteExecCall ["A3A_fnc_airTaxiRequest", 2];
    };

    default {
        // Log error if attempting to call a mode that doesn't exist
        Error_1("Air Taxi tab mode does not exist: %1", _mode);
    };
};
