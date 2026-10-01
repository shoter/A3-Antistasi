/*
Maintainer: Shoter
    Handles updating and controls on the Deliver Vehicle tab of the Main dialog.
    The player picks a garaged land vehicle, the rebel site it starts from (HQ, outpost or airport)
    and a destination on the shared fast travel map (their own position by default), sees the time
    and HR cost and blockers, and sends the request to the server.

Arguments:
    <STRING> Mode
    <ARRAY<ANY>> Array of params for the mode when applicable. Params for specific modes are documented in the modes.

Return Value:
    Nothing

Scope: Clients, Local Arguments, Local Effect
Environment: Unscheduled
Public: No
Dependencies:
    A3A_fnc_deliverVehicleCanRequest, A3A_fnc_deliverVehicleOrigins, A3A_fnc_deliverVehicleEta,
    A3A_fnc_deliverVehicleListVehicles (server reply "receiveVehicles")

Example:
    ["update"] call FUNC(deliverVehicleTab);
    ["receiveVehicles", [_vehicles]] remoteExecCall ["A3A_GUI_fnc_deliverVehicleTab", _client];  // from the server

License: APL-ND

*/

#include "..\..\dialogues\ids.inc"
#include "..\..\dialogues\defines.hpp"
#include "..\..\dialogues\textures.inc"
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_mode","update"], ["_params",[]]];

private _display = findDisplay A3A_IDD_MAINDIALOG;
if (isNull _display) exitWith {};       // dialog closed, e.g. before the server replied with the vehicle list
private _tab = _display displayCtrl A3A_IDC_DELIVERVEHICLETAB;
private _map = _display displayCtrl A3A_IDC_FASTTRAVELMAP;
private _vehicleList = _display displayCtrl A3A_IDC_DELIVERVEHICLELIST;
private _originCombo = _display displayCtrl A3A_IDC_DELIVERVEHICLEORIGINCOMBO;
private _infoText = _display displayCtrl A3A_IDC_DELIVERVEHICLEINFOTEXT;
private _commitButton = _display displayCtrl A3A_IDC_DELIVERVEHICLECOMMITBUTTON;

switch (_mode) do
{
    case ("update"):
    {
        Trace("Updating Deliver Vehicle tab");
        // Show back button
        private _backButton = _display displayCtrl A3A_IDC_MAINDIALOGBACKBUTTON;
        _backButton ctrlRemoveAllEventHandlers "MouseButtonClick";
        _backButton ctrlAddEventHandler ["MouseButtonClick", {
            ["switchTab", ["player"]] call FUNC(mainDialog);
        }];
        _backButton ctrlShow true;

        // Show the shared fast travel map
        _map ctrlShow true;

        // Ask the server for the vehicles once
        private _vehicles = _tab getVariable "vehicleList";        // nil until received, [] when none
        if (isNil "_vehicles" && { !(_tab getVariable ["vehicleListPending", false]) }) exitWith {
            ["requestVehicles"] call FUNC(deliverVehicleTab);
        };

        private _selected = _tab getVariable ["selectedVehicle", []];       // [catIndex, vehUID]
        private _origin = _tab getVariable ["selectedOrigin", ""];
        private _destPos = _map getVariable ["deliverVehicleDestination", []];
        private _lines = [];
        private _canCommit = true;

        // Vehicle
        if (isNil "_vehicles") then {
            _lines pushBack localize "STR_antistasi_dialogs_main_deliver_vehicle_loading";
            _canCommit = false;
        } else {
            private _index = _vehicles findIf { [_x # 0, _x # 1] isEqualTo _selected };
            switch (true) do {
                case (_vehicles isEqualTo []): { _lines pushBack localize "STR_antistasi_dialogs_main_deliver_vehicle_no_vehicles"; _canCommit = false };
                case (_index == -1): { _lines pushBack localize "STR_antistasi_dialogs_main_deliver_vehicle_select_vehicle"; _canCommit = false };
                default { _lines pushBack format [localize "STR_antistasi_dialogs_main_deliver_vehicle_vehicle", _vehicles # _index # 3] };
            };
        };

        // Origin
        if (_origin == "") then {
            _lines pushBack localize "STR_antistasi_dialogs_main_deliver_vehicle_no_origin";
            _canCommit = false;
        } else {
            _lines pushBack format [localize "STR_antistasi_dialogs_main_deliver_vehicle_origin", [_origin] call FUNCMAIN(localizar)];
        };

        // Destination: any clicked position, named by grid and nearest town
        if (_destPos isEqualTo []) then {
            _lines pushBack localize "STR_antistasi_dialogs_main_deliver_vehicle_select_location";
            _canCommit = false;
        } else {
            private _nearest = if (citiesX isEqualTo []) then { "" } else { [citiesX, _destPos] call BIS_fnc_nearestPosition };
            _lines pushBack format [localize "STR_antistasi_dialogs_main_deliver_vehicle_destination", mapGridPosition _destPos, _nearest];
        };

        // Distance, time and cost once origin and destination are known
        if (_origin != "" && { _destPos isNotEqualTo [] }) then {
            private _originPos = markerPos _origin;
            private _distanceKm = (round ((_originPos distance2D _destPos) / 100)) / 10;
            private _eta = [_originPos, _destPos] call FUNCMAIN(deliverVehicleEta);
            private _etaString = [[_eta] call FUNCMAIN(secondsToTimeSpan), 0, 0, false, 2] call FUNCMAIN(timeSpan_format);
            _lines pushBack format [localize "STR_antistasi_dialogs_main_deliver_vehicle_distance", _distanceKm, _etaString];
        };
        _lines pushBack format [localize "STR_antistasi_dialogs_main_deliver_vehicle_cost", A3A_deliverVehicleHR];
        _lines pushBack localize "STR_antistasi_dialogs_main_deliver_vehicle_warning";
        if (server getVariable ["hr", 0] < A3A_deliverVehicleHR) then {
            _lines pushBack localize "STR_A3A_fn_logistics_deliverVehicle_blk_no_hr";
            _canCommit = false;
        };

        // Blockers
        private _blockers = if (_destPos isEqualTo []) then {
            [player, _origin] call FUNCMAIN(deliverVehicleCanRequest)
        } else {
            [player, _origin, _destPos] call FUNCMAIN(deliverVehicleCanRequest)
        };
        if (_blockers isNotEqualTo []) then {
            _canCommit = false;
            _lines append (_blockers apply { localize ("STR_A3A_fn_logistics_deliverVehicle_blk_" + _x) });
        };

        _infoText ctrlSetStructuredText parseText (_lines joinString "<br/><br/>");
        _commitButton ctrlEnable _canCommit;
    };

    case ("requestVehicles"):
    {
        _tab setVariable ["vehicleListPending", true];
        lbClear _vehicleList;
        [player, clientOwner] remoteExecCall ["A3A_fnc_deliverVehicleListVehicles", 2];
        ["update"] call FUNC(deliverVehicleTab);
    };

    case ("receiveVehicles"):
    {
        // Takes 1 parameter: <ARRAY> list of [catIndex, vehUID, class, displayName, lockedByOther] from the server
        _params params [["_vehicles", [], [[]]]];
        Debug_1("Delivery vehicles received: %1", count _vehicles);
        _tab setVariable ["vehicleList", _vehicles];
        _tab setVariable ["vehicleListPending", false];

        _tab setVariable ["fillingVehicles", true];        // lbSetCurSel below must not count as a player selection
        lbClear _vehicleList;
        {
            _x params ["", "", "_class", "_dispName", "_lockedByOther"];
            private _index = _vehicleList lbAdd _dispName;
            _vehicleList lbSetValue [_index, _forEachIndex];
            _vehicleList lbSetPicture [_index, getText (configFile >> "CfgVehicles" >> _class >> "picture")];
            if (_lockedByOther) then {
                _vehicleList lbSetColor [_index, [1, 1, 1, 0.4]];
                _vehicleList lbSetPictureColor [_index, [1, 1, 1, 0.4]];
                _vehicleList lbSetTooltip [_index, localize "STR_antistasi_dialogs_main_deliver_vehicle_locked_tooltip"];
            };
        } forEach _vehicles;
        lbSort _vehicleList;
        _vehicleList ctrlEnable (_vehicles isNotEqualTo []);

        // Keep the previous selection if it still exists
        private _selected = _tab getVariable ["selectedVehicle", []];
        private _row = -1;
        for "_i" from 0 to (lbSize _vehicleList) - 1 do {
            private _entry = _vehicles # (_vehicleList lbValue _i);
            if ([_entry # 0, _entry # 1] isEqualTo _selected) exitWith { _row = _i };
        };
        if (_row == -1) then { _tab setVariable ["selectedVehicle", []] };
        _vehicleList lbSetCurSel _row;
        _tab setVariable ["fillingVehicles", false];

        ["update"] call FUNC(deliverVehicleTab);
    };

    case ("vehicleSelected"):
    {
        if (_tab getVariable ["fillingVehicles", false]) exitWith {};
        private _row = lbCurSel _vehicleList;
        private _selected = [];
        if (_row != -1) then {
            private _vehicles = _tab getVariable ["vehicleList", []];
            private _entry = _vehicles param [_vehicleList lbValue _row, []];
            if (_entry isNotEqualTo [] && { !(_entry # 4) }) then {
                _selected = [_entry # 0, _entry # 1];
            } else {
                // Locked by another player, not selectable
                _vehicleList lbSetCurSel -1;
            };
        };
        _tab setVariable ["selectedVehicle", _selected];
        ["update"] call FUNC(deliverVehicleTab);
    };

    case ("fillOrigins"):
    {
        // Rebel sites sorted by distance to the destination, keeps the current choice or picks the nearest
        private _destPos = _map getVariable ["deliverVehicleDestination", []];
        private _origins = [_destPos] call FUNCMAIN(deliverVehicleOrigins);
        private _current = _tab getVariable ["selectedOrigin", ""];
        if !(_current in _origins) then { _current = _origins param [0, ""] };

        _tab setVariable ["fillingOrigins", true];
        lbClear _originCombo;
        {
            private _name = [_x] call FUNCMAIN(localizar);
            if (_destPos isNotEqualTo []) then {
                _name = format ["%1 (%2 km)", _name, (round ((markerPos _x distance2D _destPos) / 100)) / 10];
            };
            private _index = _originCombo lbAdd _name;
            _originCombo lbSetData [_index, _x];
            if (_x == _current) then { _originCombo lbSetCurSel _index };
        } forEach _origins;
        _originCombo ctrlEnable (_origins isNotEqualTo []);
        _tab setVariable ["selectedOrigin", _current];
        _tab setVariable ["fillingOrigins", false];
    };

    case ("originSelected"):
    {
        if (_tab getVariable ["fillingOrigins", false]) exitWith {};
        private _row = lbCurSel _originCombo;
        private _origin = if (_row == -1) then { "" } else { _originCombo lbData _row };
        _tab setVariable ["selectedOrigin", _origin];
        ["update"] call FUNC(deliverVehicleTab);
    };

    case ("mapClicked"):
    {
        // Any point on the map is a valid destination, the driver parks as close to it as he can
        Debug_1("Deliver Vehicle map clicked: %1", _params);
        _params params ["_clickedPosition"];
        private _clickedWorldPosition = _map ctrlMapScreenToWorld _clickedPosition;
        private _destPos = [_clickedWorldPosition # 0, _clickedWorldPosition # 1, 0];

        _map setVariable ["deliverVehicleDestination", _destPos];
        _map setVariable ["selectMarkerData", [_destPos]];       // read by the selection reticle drawer
        ["fillOrigins"] call FUNC(deliverVehicleTab);
        ["update"] call FUNC(deliverVehicleTab);
    };

    case ("clearSelectedLocation"):
    {
        // Delivered to the player's own position unless they click somewhere else
        private _destPos = getPosATL player;
        _destPos set [2, 0];
        _map setVariable ["deliverVehicleDestination", _destPos];
        _map setVariable ["selectedMarker", ""];
        _map setVariable ["selectMarkerData", [_destPos]];
        _tab setVariable ["selectedOrigin", ""];
        ["fillOrigins"] call FUNC(deliverVehicleTab);
        _map ctrlMapAnimAdd [0, ctrlMapScale _map, _destPos];
        ctrlMapAnimCommit _map;
    };

    case ("commitButtonClicked"):
    {
        private _selected = _tab getVariable ["selectedVehicle", []];
        private _origin = _tab getVariable ["selectedOrigin", ""];
        private _destPos = _map getVariable ["deliverVehicleDestination", []];
        if (_selected isEqualTo [] || _origin == "" || _destPos isEqualTo []) exitWith {};
        _selected params ["_catIndex", "_vehUID"];
        closeDialog 1;
        [player, _catIndex, _vehUID, _origin, _destPos, clientOwner] remoteExecCall ["A3A_fnc_deliverVehicleRequest", 2];
    };

    default {
        // Log error if attempting to call a mode that doesn't exist
        Error_1("Deliver Vehicle tab mode does not exist: %1", _mode);
    };
};
