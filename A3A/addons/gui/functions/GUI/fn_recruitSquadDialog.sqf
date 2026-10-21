/*
Maintainer: Caleb Serafin, DoomMetal
    Handles the initialization and updating of the Recruit Squad dialog.
    This function should only be called from RecruitSquadDialog onLoad and control activation EHs.

Arguments:
    <STRING> Mode, only possible value for this dialog is "onLoad"
    <ARRAY<ANY>> Array of params for the mode when applicable. Params for specific modes are documented in the modes.

Return Value:
    Nothing

Scope: Clients, Local Arguments, Local Effect
Environment: Scheduled for onLoad mode / Unscheduled for everything else unless specified
Public: No
Dependencies:
    None

Example:
    ["onLoad"] spawn FUNC(recruitDialog); // initialization
    ["update"] spawn FUNC(recruitDialog); // update

License: APL-ND

*/

#include "..\..\dialogues\ids.inc"
#include "..\..\dialogues\defines.hpp"
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params[["_mode","onLoad"], ["_params",[]]];

switch (_mode) do
{
    case ("onLoad"):
    {
        Debug("RecruitSquadDialog onLoad starting...");

        // Separated because initial "onLoad" needs scheduled env while other updates needs unscheduled
        ["update"] call FUNC(recruitSquadDialog);

        Debug("RecruitSquadDialog onLoad complete.");
    };

    case ("update"):
    {
        private _display = findDisplay A3A_IDD_RECRUITSQUADDIALOG;

        private _includeVehicleCheckbox = _display displayCtrl A3A_IDC_SQUADINCLUDEVEHICLECHECKBOX;

        // Get vehicle CB state
        private _includeVehicle = cbChecked _includeVehicleCheckbox;

        private _money = server getVariable "resourcesFIA";
        private _hr = server getVariable "hr";

        {
            private _icon = _display displayCtrl _x#0;
            private _priceText = _display displayCtrl _x#1;
            private _button = _display displayCtrl _x#2;
            private _group = if ((_x#3) isEqualTo []) then {
                if (_x#0 isEqualTo A3A_IDC_RECRUITAATRUCKICON) then {
                    FactionGet(reb,"staticAA")#0
                } else {
                    []
                };
            } else {selectRandom (_x#3)};
            if (_group isEqualTo []) then {
                _button ctrlEnable false;
                _button ctrlSetTooltip localize "STR_antistasi_recruit_squad_notCompatible";
                _icon ctrlSetTextColor ([A3A_COLOR_BUTTON_BACKGROUND_DISABLED] call FUNC(configColorToArray));
                continue
            };
            private _hasVehicle = (_x#0 in [A3A_IDC_RECRUITMGCARICON, A3A_IDC_RECRUITATCARICON, A3A_IDC_RECRUITAATRUCKICON]);
            private _vehicle = "";
            if (_includeVehicle && {!_hasVehicle}) then {
                _vehicle = [_group] call A3A_fnc_getHCSquadVehicleType;
            };
            _button setVariable ["squadType", _group];
            _button setVariable ["vehicle", if (_hasVehicle) then {""} else {_vehicle}];
            private _price = [_group, _vehicle] call A3A_fnc_getHCSquadPrice;
            _price params ["_reqMoney", "_reqHR"];
            _priceText ctrlSetText (format ["%1 € %2 HR", _reqMoney, _reqHR]);
            if (_money < _reqMoney || _hr < _reqHR) then {
                _button ctrlEnable false;
                _button ctrlSetTooltip localize "STR_antistasi_recruit_squad_error";
                _icon ctrlSetTextColor ([A3A_COLOR_BUTTON_BACKGROUND_DISABLED] call FUNC(configColorToArray));
            };
        } forEach [
            // Icon IDC, Price IDC, Button IDC, Group
            [A3A_IDC_RECRUITINFSQUADICON, A3A_IDC_RECRUITINFSQUADPRICE, A3A_IDC_RECRUITINFSQUADBUTTON, [FactionGet(reb,"groupSquad")]],
            [A3A_IDC_RECRUITENGSQUADICON, A3A_IDC_RECRUITENGSQUADPRICE, A3A_IDC_RECRUITENGSQUADBUTTON, [FactionGet(reb,"groupSquadEng")]],
            [A3A_IDC_RECRUITINFTEAMICON, A3A_IDC_RECRUITINFTEAMPRICE, A3A_IDC_RECRUITINFTEAMBUTTON, [FactionGet(reb,"groupMedium")]],
            [A3A_IDC_RECRUITMGTEAMICON, A3A_IDC_RECRUITMGTEAMPRICE, A3A_IDC_RECRUITMGTEAMBUTTON, FactionGet(reb,"staticMGs")],
            [A3A_IDC_RECRUITATTEAMICON, A3A_IDC_RECRUITATTEAMPRICE, A3A_IDC_RECRUITATTEAMBUTTON, [FactionGet(reb,"groupAT")]],
            [A3A_IDC_RECRUITMORTARTEAMICON, A3A_IDC_RECRUITMORTARTEAMPRICE, A3A_IDC_RECRUITMORTARTEAMBUTTON, FactionGet(reb,"staticMortars")],
            [A3A_IDC_RECRUITSNIPERTEAMICON, A3A_IDC_RECRUITSNIPERTEAMPRICE, A3A_IDC_RECRUITSNIPERTEAMBUTTON, [FactionGet(reb,"groupSniper")]],
            [A3A_IDC_RECRUITMGCARICON, A3A_IDC_RECRUITMGCARPRICE, A3A_IDC_RECRUITMGCARBUTTON, FactionGet(reb,"vehiclesLightArmed")],
            [A3A_IDC_RECRUITATCARICON, A3A_IDC_RECRUITATCARPRICE, A3A_IDC_RECRUITATCARBUTTON, FactionGet(reb,"vehiclesAT")],
            [A3A_IDC_RECRUITAATRUCKICON, A3A_IDC_RECRUITAATRUCKPRICE, A3A_IDC_RECRUITAATRUCKBUTTON, FactionGet(reb,"vehiclesAA")]
        ];
        // Readability improvement? Yeah, probably...

        // Custom squads from the squad composer. They go on foot when the vehicle cannot seat the whole squad
        private _names = createHashMapFromArray A3A_CUSTOM_SQUAD_UNIT_NAMES;
        {
            _x params ["_index", "_iconIDC", "_priceIDC", "_buttonIDC"];
            private _icon = _display displayCtrl _iconIDC;
            private _priceText = _display displayCtrl _priceIDC;
            private _button = _display displayCtrl _buttonIDC;
            (A3A_customSquads param [_index, ["", []]]) params ["_abbreviation", "_counts"];
            private _group = [_index] call A3A_fnc_customSquadUnits;

            private _vehicle = "";
            private _fits = true;
            if (_includeVehicle) then {
                _vehicle = [_group] call A3A_fnc_getHCSquadVehicleType;
                if (isNil "_vehicle") then { _vehicle = "" };
                if (_vehicle != "" && {count _group > ([_vehicle, true] call BIS_fnc_crewCount)}) then { _vehicle = ""; _fits = false };
            };

            private _composition = [format ["%1 x1", localize (_names get "unitSL")]];
            { _composition pushBack format ["%1 x%2", localize (_names getOrDefault [_x # 0, ""]), _x # 1] } forEach _counts;
            private _tooltip = format [localize "STR_antistasi_dialogs_recruit_squad_custom_tooltip", _abbreviation, _composition joinString ", "];
            if !(_fits) then { _tooltip = _tooltip + " " + localize "STR_antistasi_dialogs_recruit_squad_custom_on_foot" };

            _button ctrlSetText format [localize "STR_antistasi_dialogs_recruit_squad_custom", _index + 1, _abbreviation];
            _button ctrlSetTooltip _tooltip;
            _button setVariable ["squadType", _group];
            _button setVariable ["vehicle", _vehicle];
            _button setVariable ["idPrefix", _abbreviation];
            ([_group, _vehicle] call A3A_fnc_getHCSquadPrice) params ["_reqMoney", "_reqHR"];
            _priceText ctrlSetText (format ["%1 € %2 HR", _reqMoney, _reqHR]);
            private _canAfford = _money >= _reqMoney && _hr >= _reqHR;
            _button ctrlEnable _canAfford;
            _icon ctrlSetTextColor ([[A3A_COLOR_BUTTON_BACKGROUND_DISABLED] call FUNC(configColorToArray), [A3A_COLOR_TEXT_DARKER] call FUNC(configColorToArray)] select _canAfford);
            if !(_canAfford) then { _button ctrlSetTooltip localize "STR_antistasi_recruit_squad_error" };
        } forEach [
            // Custom squad index, Icon IDC, Price IDC, Button IDC
            [0, A3A_IDC_RECRUITCUSTOM1ICON, A3A_IDC_RECRUITCUSTOM1PRICE, A3A_IDC_RECRUITCUSTOM1BUTTON],
            [1, A3A_IDC_RECRUITCUSTOM2ICON, A3A_IDC_RECRUITCUSTOM2PRICE, A3A_IDC_RECRUITCUSTOM2BUTTON]
        ];
    };

    case ("buySquad"):
    {
        private _button = (_params # 0) # 0;
        private _squadType = _button getVariable ["squadType", []];
        private _vehicle = _button getVariable ["vehicle", ""];
        // Get vehicle CB state
        private _display = findDisplay A3A_IDD_RECRUITSQUADDIALOG;
        private _includeVehicleCheckbox = _display displayCtrl A3A_IDC_SQUADINCLUDEVEHICLECHECKBOX;
        private _includeVehicle = cbChecked _includeVehicleCheckbox;

        // Custom squads carry the abbreviation chosen in the squad composer
        private _idPrefix = _button getVariable ["idPrefix", ""];

        closeDialog 1;
        // Previous format, to be changed back to this
        // [_squadType, _vehicle] spawn A3A_fnc_addFIAsquadHC;
        [_squadType, "", _includeVehicle, _idPrefix] spawn A3A_fnc_addFIAsquadHC;
    };

    default {
        // Log error if attempting to call a mode that doesn't exist
        Error_1("RecruitSquadDialog mode does not exist: %1", _mode);
    };
};
