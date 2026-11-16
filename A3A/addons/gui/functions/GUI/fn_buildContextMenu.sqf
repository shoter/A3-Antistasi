/*
Maintainer: Tiny
    Builds the context menu on the main player page based on a variety of conditions

Arguments:
    <OBJ> Target vehicle, if a custom param is needed. Usually not used.

Return Value:
    Nothing

Scope: Clients, Local Arguments, Local Effect
Environment: Unscheduled, probably
Public: No
Dependencies:
    None

Example:
    [cursorObject] call FUNC(buildContextMenu);

License: APL-ND

*/

#include "..\..\dialogues\ids.inc"
#include "..\..\dialogues\defines.hpp"
#include "..\..\dialogues\textures.inc"
#include "..\..\script_component.hpp"
#include "..\..\..\garage\CfgDefines.inc"
FIX_LINE_NUMBERS()

#define CONSTRUCTIMAGE "\A3\EditorPreviews_F_Exp\Data\CfgVehicles\Land_WoodenCrate_01_F.jpg"
#define HQIMAGE "\A3\EditorPreviews_F\Data\CfgVehicles\Flag_FIA_F.jpg"

params [["_vehicle", cursorObject, [objNull]]];

// Vehicle section
private _contextGroup = _display displayCtrl A3A_IDC_PLAYERCONTEXTGROUP;
private _noActionsGroup = _display displayCtrl A3A_IDC_NOACTIONSGROUP;

private _contextSingle1Button = _display displayCtrl A3A_IDC_CONTEXTSINGLE1BUTTON;
private _contextSingle2Button = _display displayCtrl A3A_IDC_CONTEXTSINGLE2BUTTON;
private _contextSingle3Button = _display displayCtrl A3A_IDC_CONTEXTSINGLE3BUTTON;
private _contextSingle4Button = _display displayCtrl A3A_IDC_CONTEXTSINGLE4BUTTON;

private _contextHoriz1Button = _display displayCtrl A3A_IDC_CONTEXTHORIZ1BUTTON;
private _contextHoriz2Button = _display displayCtrl A3A_IDC_CONTEXTHORIZ2BUTTON;

private _vehicleNameLabel = _display displayCtrl A3A_IDC_VEHICLENAMELABEL;
private _vehicleNameBackground = _display displayCtrl A3A_IDC_VEHICLENAMEBACKGROUND;
private _vehiclePicture = _display displayCtrl A3A_IDC_VEHICLEPICTURE;

private _containerLabel = _display displayCtrl A3A_IDC_CONTEXTLABEL;

private _disableAll = [_contextSingle1Button, _contextSingle2Button, _contextSingle3Button, _contextSingle4Button, _contextHoriz1Button, _contextHoriz2Button, _noActionsGroup];
// The no-actions case below hides these, so bring them back for every rebuild. Before hiding the
// buttons: showing the group shows all its children too
_contextGroup ctrlShow true;
_vehicleNameBackground ctrlShow true;
{_x ctrlShow false; _x ctrlEnable false; _x ctrlSetTooltip ""; _x ctrlRemoveAllEventHandlers "ButtonClick";} forEach _disableAll;

private _vehType = if ( !isClass (configFile >> "CfgVehicles" >> typeOf _vehicle) ) then { -1 } else {[typeOf _vehicle] call HR_GRG_fnc_getCatIndex};
private _containerTitle = "";

// First case: Has valid vehicle as cursorObject
// Second case: Has building (built or unbuild) under cursor
// Third case: Is near HQ
// Last case: idk just default to nothing LOL

switch (true) do {
    case (!(isNull _vehicle) && {(_vehicle distance player < 25) && { // Check if vehicle is eligible for garage / sell, not a dude or house etc.
        (_vehType >= 0) ||
        (_vehicle getVariable ['A3A_canGarage', false])
    }}): {
        private _className = typeOf _vehicle;
        private _configClass = configFile >> "CfgVehicles" >> _className;
        private _displayName = getText (_configClass >> "displayName");
        private _editorPreview = getText (_configClass >> "editorPreview");

        _vehicleNameLabel ctrlSetText _displayName;
        // For some reason the text control becomes active showing an ugly
        // white border, we disable it here to avoid that
        _vehicleNameLabel ctrlEnable false;

        _vehiclePicture ctrlSetText _editorPreview;
        
        private _garageContextOptions = switch (true) do {
            case (_vehType in [3,4]): {
                _containerTitle = localize "STR_antistasi_dialogs_main_context_title_aircraft";
                [["garage", _contextSingle1Button], ["vehArsenal", _contextSingle2Button], ["RRR", _contextSingle3Button], ["airSupport", _contextSingle4Button]];
            };
            _containerTitle = localize "STR_antistasi_dialogs_main_context_title_vehicle";
            case ((_vehType != 7) && {(_vehicle isNil "markerX")}): {
                [["garage", _contextSingle1Button], ["vehArsenal", _contextSingle2Button], ["RRR", _contextSingle3Button], ["addToGarrison", _contextSingle4Button]];
            };
            case ((_vehType == 7) || {!(_vehicle isNil "markerX")}): {
                [["garage", _contextSingle1Button], ["vehArsenal", _contextSingle2Button], ["RRR", _contextSingle3Button], ["toggleAI", _contextSingle4Button]];
            };
            default {
                [["garage", _contextSingle1Button], ["vehArsenal", _contextSingle2Button], ["RRR", _contextHoriz2Button]];
            };
        };

        // Why the garage button is greyed out, "" when it is not. Read by "vehArsenal", which comes after "garage" in every list.
        private _garageBlocker = "";

        {
            _x params ["_action", "_button"];
            _button ctrlShow true;
            switch (_action) do {
                case ("garage"): {
                    // Two-line label, the button is a shortcut button (see ContextActionSingle1 in mainDialog.hpp)
                    _button ctrlSetStructuredText parseText localize "STR_antistasi_dialogs_main_context_button_garage_twoLines";
                    // Garage check
                    private _friendlyMarkers = (["Synd_HQ"] +outposts + seaports + airportsX + factories + resourcesX) select {sidesX getVariable [_x,sideUnknown] == teamPlayer}; //rebel locations with a flag
                    private _inArea = _friendlyMarkers findIf { count ([player, _vehicle] inAreaArray _x) > 1 };
                    if !(_inArea > -1) exitWith {
                        _button ctrlEnable false;
                        _garageBlocker = "STR_antistasi_dialogs_main_context_garage_away";
                        _button ctrlSetTooltip localize _garageBlocker;
                    };
                    private _inArea = true;
                    if (_vehType in HR_GRG_BLOCKAIRINDEX) then {
                        private _friendlyMarkers = (airportsX) select {sidesX getVariable [_x,sideUnknown] == teamPlayer};
                        private _nearestHelipads = (nearestObjects [_vehicle, ["a3a_helipad"], 30, true]);
                        _inArea = ((_friendlyMarkers findIf { _vehicle inArea _x} != -1) || (count _nearestHelipads > 0 && (_vehicle isKindOf "Helicopter")));              
                    };
                    if !(_inArea) exitWith {
                        _button ctrlEnable false;
                        _garageBlocker = ["STR_antistasi_dialogs_main_context_garage_airbase", "STR_antistasi_dialogs_main_context_garage_airbase_helipad"] select (_vehType == (HR_GRG_HELIPADACCESSIBLE)#0);
                        _button ctrlSetTooltip localize _garageBlocker;
                    };
                    if (_vehicle getVariable ['A3A_canGarage', false]) then {
                        _button ctrlSetTooltip localize "STR_antistasi_dialogs_main_context_garage_utility";
                    };
                    _button setVariable ["vehicle", _vehicle];
                    _button ctrlAddEventHandler ["ButtonClick", {closeDialog 0; [(_this#0) getVariable "vehicle", clientOwner, call HR_GRG_dLock, player] remoteExecCall ['HR_GRG_fnc_addVehicle',2];}];
                    _button ctrlEnable true;
                };
                case ("vehArsenal"): {
                    // Replaces the old "Vehicle Arsenal" scroll action of the HQ garage (vehicleBox). Same rules as the garage
                    // button, but only in the HQ area where the garage stands: never at outposts, airbases or other rebel flags.
                    _button ctrlSetStructuredText parseText localize "STR_antistasi_dialogs_main_context_button_vehArsenal_twoLines";
                    if (_garageBlocker isNotEqualTo "") exitWith {
                        _button ctrlSetTooltip localize _garageBlocker;
                    };
                    if (count ([player, _vehicle] inAreaArray "Synd_HQ") < 2) exitWith {
                        _button ctrlSetTooltip localize "STR_antistasi_dialogs_main_context_vehArsenal_hqOnly";
                    };
                    if (getNumber (_configClass >> "maximumLoad") <= 0) exitWith {
                        _button ctrlSetTooltip localize "STR_antistasi_dialogs_main_context_vehArsenal_noCargo";
                    };
                    // Set while another player has this vehicle's cargo open in the arsenal, see fn_vehicleArsenal "CustomInit"
                    private _user = _vehicle getVariable ["jnva_user", objNull];
                    if (!isNull _user && {_user != player} && {alive _user} && {isPlayer _user}) exitWith {
                        _button ctrlSetTooltip localize "STR_A3A_JNA_vehicle_in_use";
                    };
                    _button setVariable ["vehicle", _vehicle];
                    _button ctrlAddEventHandler ["ButtonClick", {
                        private _veh = (_this#0) getVariable "vehicle";
                        closeDialog 0;
                        if !(missionNamespace getVariable ["arsenalInit", false]) exitWith {};
                        // The arsenalOpened handler in fn_arsenal_init picks this up and opens the vehicle arsenal for _veh
                        jnva_requestedVehicle = [_veh, diag_tickTime];
                        call JN_fnc_arsenal_handleAction;
                    }];
                    _button ctrlSetTooltip localize "STR_antistasi_dialogs_main_context_vehArsenal_tooltip";
                    _button ctrlEnable true;
                };
                case ("RRR"): {
                    _button ctrlSetText "REARM";
                    _button ctrlAddEventHandler ["ButtonClick", {closeDialog 0; createDialog "A3A_vehServiceDialog"}];
                    _button ctrlSetTooltip "Rearm this vehicle";
                    _button ctrlEnable true;
                };
                case ("airSupport"): {
                    _button ctrlSetText localize "STR_antistasi_dialogs_main_context_button_addBombRun";
                    // Disable "add to air support" button if vehicle is not eligible
                    if (player isNotEqualTo theBoss) exitWith {
                        _button ctrlSetTooltip localize "STR_antistasi_dialogs_main_commander_only_tooltip";
                    };
                    //Valid area to convert to air support
                    private _friendlyMarkers = (["Synd_HQ"] + airportsX) select {sidesX getVariable [_x,sideUnknown] == teamPlayer}; //rebel locations with a flag
                    private _inArea = _friendlyMarkers findIf { count ([player, _vehicle] inAreaArray _x) > 1 };
                    if (!(_inArea > -1) && (_vehicle isKindOf "Air")) exitWith { 
                        _button ctrlSetTooltip localize "STR_antistasi_dialogs_main_context_addBombRun_nearValid";
                    };
                    _button setVariable ["vehicle", _vehicle];
                    _button ctrlAddEventHandler ["ButtonClick", {closeDialog 0; [(_this#0) getVariable "vehicle"] call A3A_fnc_addBombRun}];
                    _button ctrlEnable true;
                };
                case ("toggleAI"): {
                    _button ctrlSetText localize "STR_antistasi_dialogs_main_context_button_toggleAI1";
                    private _isLocked = !(_vehicle isNil "lockedForAI");
                    if (_vehicle getVariable ['ownerSide', teamPlayer] != teamPlayer) exitWith {
                        _button ctrlSetTooltip localize "STR_antistasi_dialogs_main_context_gen_notRebVic";
                    };
                    _button setVariable ["vehicle", _vehicle];
                    if (_isLocked) then {
                        _button ctrlAddEventHandler ["ButtonClick", {closeDialog 0; [(_this#0) getVariable "vehicle"] call A3A_fnc_unlockStatic}];
                    } else {
                        _button ctrlSetText localize "STR_antistasi_dialogs_main_context_button_toggleAI2";
                        _button ctrlAddEventHandler ["ButtonClick", {closeDialog 0; [(_this#0) getVariable "vehicle"] call A3A_fnc_lockStatic}];
                    };
                    _button ctrlEnable true;
                };
                case ("addToGarrison"): {
                    _button ctrlSetText "Add to garrison";
                    if (_vehicle getVariable ['ownerSide', teamPlayer] != teamPlayer) exitWith {
                        _button ctrlSetTooltip localize "STR_antistasi_dialogs_main_context_gen_notRebVic";
                    };
                    if !(_vehicle isNil 'markerX') exitWith {
                        _button ctrlSetTooltip localize "STR_antistasi_dialogs_main_context_addToGarrison_alreadyIn";
                    };
                    private _marker = [getPosATL _vehicle] call A3A_fnc_getMarkerForPos;
                    if (_marker == "" or { sidesX getVariable _marker != teamPlayer }) then {
                        _button ctrlSetTooltip localize "STR_A3A_garrison_vehicle_outside";
                    };
                    if (crew _vehicle isNotEqualTo []) exitWith {
                        _button ctrlSetTooltip localize "STR_antistasi_dialogs_main_context_addToGarrison_crewed";
                    };
                    _button setVariable ["vehicle", _vehicle];
                    _button ctrlAddEventHandler ["ButtonClick", {closeDialog 0; [(_this#0) getVariable "vehicle", player] call A3A_fnc_actionGarrisonVehicle}];
                    _button ctrlEnable true;
                };
                case ("empty");
                default {

                };
            };

        } forEach _garageContextOptions;
    };
    case (cursorObject in A3A_unbuiltObjects || {cursorobject getvariable ["A3A_building", false]}): {
        _containerTitle = localize "STR_antistasi_dialogs_main_context_title_construction";

        _vehiclePicture ctrlSetText CONSTRUCTIMAGE;
        _vehicleNameLabel ctrlSetText localize "STR_antistasi_dialogs_main_context_label_construction";
        _hideIconsButton = _contextHoriz1Button;
        _hideActionsButton = _contextHoriz2Button;
        _hideIconsButton ctrlShow true;
        _hideActionsButton ctrlShow true;
        _hideIconsButton ctrlSetText localize (["STR_antistasi_dialogs_main_context_button_showIcons","STR_antistasi_dialogs_main_context_button_hideIcons"] select A3A_drawBuilderIcons);
        _hideActionsButton ctrlSetText localize (["STR_antistasi_dialogs_main_context_button_showActions", "STR_antistasi_dialogs_main_context_button_hideActions"] select A3A_showBuilderActions);
        if !(player call A3A_fnc_isEngineer) exitWith {
            _hideIconsButton ctrlSetTooltip localize "STR_antistasi_dialogs_main_context_construction_needEngineer";
            _hideActionsButton ctrlSetTooltip localize "STR_antistasi_dialogs_main_context_construction_needEngineer";
        };
        _hideIconsButton ctrlEnable true;
        _hideActionsButton ctrlEnable true;
        _hideIconsButton ctrlAddEventHandler ["ButtonClick", {closeDialog 0; A3A_drawBuilderIcons = !A3A_drawBuilderIcons;}];
        _hideActionsButton ctrlAddEventHandler ["ButtonClick", {closeDialog 0; A3A_showBuilderActions = !A3A_showBuilderActions;}]; // hm. dialogs too slow to refresh entire thing
    };
    case (markerpos "Synd_HQ" distance player < 75): {
        _containerTitle = localize "STR_antistasi_dialogs_main_context_title_HQ";

        _vehiclePicture ctrlSetText HQIMAGE;
        _vehicleNameLabel ctrlSetText localize "STR_antistasi_dialogs_main_context_label_HQ";
        // two fixed buttons
        _roleSelectButton = _contextHoriz1Button;
        _vehArsenalButton = _contextHoriz2Button;
        _roleSelectButton ctrlShow true;
        _vehArsenalButton ctrlShow true;
        _roleSelectButton ctrlSetText localize "STR_antistasi_dialogs_main_context_HQ_changeRole";
        _vehArsenalButton ctrlSetText localize "STR_antistasi_dialogs_main_context_HQ_vehArsenal";

        _roleSelectButton ctrlAddEventHandler ["ButtonClick", {createDialog "A3A_RoleSelectDialog";}];
        _roleSelectButton ctrlEnable true;
        private _veh = objectParent player;
        if ((_veh == player) || {player != (driver _veh)}) exitWith {
            _vehArsenalButton ctrlSetTooltip localize "STR_antistasi_dialogs_main_context_HQ_beDriver";
        };
        _vehArsenalButton ctrlAddEventHandler ["ButtonClick", {closeDialog 0; call JN_fnc_arsenal_handleAction}];
        _vehArsenalButton ctrlEnable true;
    };
    default {
        _contextGroup ctrlShow false;
        _noActionsGroup ctrlShow true;
        _vehicleNameBackground ctrlShow false;
    };
};

if (_containerTitle != "") then {
    _containerLabel ctrlSetText ([localize "STR_antistasi_dialogs_main_context_title_main",_containerTitle] joinString ": ");
};
