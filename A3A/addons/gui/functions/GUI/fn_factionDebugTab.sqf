/*
Maintainer: Shoter
    Handles the Factions tab of the Main Dialog: debug numbers of the enemy factions for admins.
    The server answers through A3A_fnc_factionDebugData, the tab asks again every 2 seconds while it is shown.

Arguments:
    <STRING> Mode, e.g. "update", "dataReceived"
    <ARRAY<ANY>> Array of params for the mode when applicable. Params for specific modes are documented in the modes.

Return Value:
    Nothing

Scope: Clients, Local Arguments, Local Effect
Environment: Unscheduled
Public: No
Dependencies:
    None

Example:
    ["update"] call A3A_GUI_fnc_factionDebugTab;

License: APL-ND

*/

#include "..\..\dialogues\ids.inc"
#include "..\..\dialogues\defines.hpp"
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params[
    ["_mode","update"],
    ["_params",[]]
];

private _display = findDisplay A3A_IDD_MAINDIALOG;
private _tab = _display displayCtrl A3A_IDC_FACTIONDEBUGTAB;
private _list = _display displayCtrl A3A_IDC_FACTIONDEBUGLIST;
private _status = _display displayCtrl A3A_IDC_FACTIONDEBUGSTATUS;

switch (_mode) do
{
    case ("update"):
    {
        if (isNull _display) exitWith {};

        (_display displayCtrl A3A_IDC_FACTIONDEBUGHEADER_OCC) ctrlSetText ((missionNamespace getVariable ["A3A_faction_occ", createHashMap]) getOrDefault ["name", localize "STR_antistasi_dialogs_main_factiondebug_occupants"]);
        (_display displayCtrl A3A_IDC_FACTIONDEBUGHEADER_INV) ctrlSetText ((missionNamespace getVariable ["A3A_faction_inv", createHashMap]) getOrDefault ["name", localize "STR_antistasi_dialogs_main_factiondebug_invaders"]);

        if ((_tab getVariable ["factionData", []]) isEqualTo []) then {
            lnbClear _list;
            _status ctrlSetText localize "STR_antistasi_dialogs_main_factiondebug_loading";
        } else {
            ["render"] call FUNC(factionDebugTab);
        };

        // Ask the server again every 2 seconds until the tab is hidden or the dialog closes
        terminate (_tab getVariable ["refreshLoop", scriptNull]);
        private _refreshLoop = [_tab] spawn {
            params ["_tab"];
            while {!isNull _tab && {ctrlShown _tab}} do {
                [] remoteExecCall ["A3A_fnc_factionDebugData", 2];
                uiSleep 2;
            };
        };
        _tab setVariable ["refreshLoop", _refreshLoop];
    };

    case ("dataReceived"):
    {
        // Takes 2 parameters: <HASHMAP> war-wide balance values, <ARRAY<HASHMAP>> Occupants and Invaders values, sent by A3A_fnc_factionDebugData
        _params params [["_global", createHashMap, [createHashMap]], ["_sides", [], [[]]]];
        if (isNull _display || {count _sides != 2}) exitWith {};
        _tab setVariable ["factionData", [_global, _sides]];
        ["render"] call FUNC(factionDebugTab);
    };

    case ("render"):
    {
        if (isNull _display) exitWith {};
        (_tab getVariable ["factionData", []]) params [["_global", createHashMap], ["_sides", [createHashMap, createHashMap]]];
        _sides params ["_occ", "_inv"];

        private _fnc_yesNo = { localize (["STR_antistasi_dialogs_main_factiondebug_no", "STR_antistasi_dialogs_main_factiondebug_yes"] select _this) };
        private _fnc_ofMax = { format ["%1 / %2", (_this#0) toFixed 0, (_this#1) toFixed 0] };
        // Income per 10 minutes from the per-minute rates, index 0 defence, 1 attack
        private _fnc_income = {
            params ["_data", "_index"];
            private _rates = _data getOrDefault ["rates", []];
            if (_rates isEqualTo []) exitWith { "-" };
            (10 * (_rates#_index)) toFixed 1
        };

        // Rows are [label, Occupants text, Invaders text, tooltip, section header]
        private _rows = [];
        private _fnc_section = { _rows pushBack [localize _this, "", "", "", true] };
        private _fnc_sideRow = {
            params ["_labelKey", "_code", ["_tooltipKey", ""]];
            _rows pushBack [localize _labelKey, _occ call _code, _inv call _code, [localize _tooltipKey, ""] select (_tooltipKey == ""), false];
        };
        private _fnc_globalRow = {
            params ["_labelKey", "_text", ["_tooltipKey", ""]];
            _rows pushBack [localize _labelKey, _text, "", [localize _tooltipKey, ""] select (_tooltipKey == ""), false];
        };

        "STR_antistasi_dialogs_main_factiondebug_section_resources" call _fnc_section;
        ["STR_antistasi_dialogs_main_factiondebug_defence", {
            private _rates = _this getOrDefault ["rates", []];
            if (_rates isEqualTo []) exitWith { (_this get "defRes") toFixed 0 };
            [_this get "defRes", _rates#2] call _fnc_ofMax
        }, "STR_antistasi_dialogs_main_factiondebug_defence_tooltip"] call _fnc_sideRow;
        ["STR_antistasi_dialogs_main_factiondebug_defence_income", { [_this, 0] call _fnc_income }, "STR_antistasi_dialogs_main_factiondebug_income_tooltip"] call _fnc_sideRow;
        ["STR_antistasi_dialogs_main_factiondebug_attack", { (_this get "atkRes") toFixed 0 }, "STR_antistasi_dialogs_main_factiondebug_attack_tooltip"] call _fnc_sideRow;
        ["STR_antistasi_dialogs_main_factiondebug_attack_income", { [_this, 1] call _fnc_income }, "STR_antistasi_dialogs_main_factiondebug_income_tooltip"] call _fnc_sideRow;
        ["STR_antistasi_dialogs_main_factiondebug_next_attack", {
            if !(_this get "active") exitWith { localize "STR_antistasi_dialogs_main_factiondebug_inactive" };
            private _attack = _this get "atkRes";
            if (_attack >= 0) exitWith {
                localize (["STR_antistasi_dialogs_main_factiondebug_attack_due", "STR_antistasi_dialogs_main_factiondebug_attack_waiting"] select (_global getOrDefault ["bigAttack", false]))
            };
            private _rates = _this getOrDefault ["rates", []];
            if (_rates isEqualTo [] || {_rates#1 <= 0}) exitWith { "-" };
            format [localize "STR_antistasi_dialogs_main_factiondebug_minutes", ceil (-_attack / (_rates#1))]
        }, "STR_antistasi_dialogs_main_factiondebug_next_attack_tooltip"] call _fnc_sideRow;

        "STR_antistasi_dialogs_main_factiondebug_section_aggression" call _fnc_section;
        ["STR_antistasi_dialogs_main_factiondebug_aggression", {
            format [localize "STR_antistasi_dialogs_main_factiondebug_aggression_value", round (_this get "aggression"), _this get "aggressionLevel"]
        }] call _fnc_sideRow;
        ["STR_antistasi_dialogs_main_factiondebug_aggression_events", { str (_this get "aggressionEvents") }, "STR_antistasi_dialogs_main_factiondebug_aggression_events_tooltip"] call _fnc_sideRow;
        ["STR_antistasi_dialogs_main_factiondebug_losses", {
            format [localize "STR_antistasi_dialogs_main_factiondebug_losses_value", _this get "damageValue", _this get "damageEvents"]
        }, "STR_antistasi_dialogs_main_factiondebug_losses_tooltip"] call _fnc_sideRow;
        ["STR_antistasi_dialogs_main_factiondebug_hq_knowledge", { str round (100 * (_this get "hqKnowledge")) + "%" }, "STR_antistasi_dialogs_main_factiondebug_hq_knowledge_tooltip"] call _fnc_sideRow;

        "STR_antistasi_dialogs_main_factiondebug_section_sites" call _fnc_section;
        {
            private _index = _forEachIndex;
            [_x, { str ((_this get "sites") # _index) }] call _fnc_sideRow;
        } forEach [
            "STR_antistasi_dialogs_main_factiondebug_airbases",
            "STR_antistasi_dialogs_main_factiondebug_outposts",
            "STR_antistasi_dialogs_main_factiondebug_seaports",
            "STR_antistasi_dialogs_main_factiondebug_factories",
            "STR_antistasi_dialogs_main_factiondebug_resources",
            "STR_antistasi_dialogs_main_factiondebug_towns"
        ];
        ["STR_antistasi_dialogs_main_factiondebug_troops", { (_this get "troops") call _fnc_ofMax }, "STR_antistasi_dialogs_main_factiondebug_troops_tooltip"] call _fnc_sideRow;
        ["STR_antistasi_dialogs_main_factiondebug_vehicles", { str (_this get "vehicles") }] call _fnc_sideRow;
        ["STR_antistasi_dialogs_main_factiondebug_police", { (_this get "police") call _fnc_ofMax }, "STR_antistasi_dialogs_main_factiondebug_troops_tooltip"] call _fnc_sideRow;

        "STR_antistasi_dialogs_main_factiondebug_section_supports" call _fnc_section;
        ["STR_antistasi_dialogs_main_factiondebug_strikes", { str (_this get "strikes") }, "STR_antistasi_dialogs_main_factiondebug_strikes_tooltip"] call _fnc_sideRow;
        ["STR_antistasi_dialogs_main_factiondebug_supports", { str (_this get "supports") }, "STR_antistasi_dialogs_main_factiondebug_supports_tooltip"] call _fnc_sideRow;
        ["STR_antistasi_dialogs_main_factiondebug_support_spend", { (_this get "supportSpend") toFixed 0 }] call _fnc_sideRow;

        "STR_antistasi_dialogs_main_factiondebug_section_balance" call _fnc_section;
        ["STR_antistasi_dialogs_main_factiondebug_active", { (_this get "active") call _fnc_yesNo }, "STR_antistasi_dialogs_main_factiondebug_active_tooltip"] call _fnc_sideRow;
        ["STR_antistasi_dialogs_main_factiondebug_players", str (_global get "activePlayers")] call _fnc_globalRow;
        ["STR_antistasi_dialogs_main_factiondebug_war_tier", str (_global get "tierWar")] call _fnc_globalRow;
        ["STR_antistasi_dialogs_main_factiondebug_player_scale", (_global get "playerScale") toFixed 2, "STR_antistasi_dialogs_main_factiondebug_player_scale_tooltip"] call _fnc_globalRow;
        ["STR_antistasi_dialogs_main_factiondebug_resource_rate", (_global get "resourceRate") toFixed 1, "STR_antistasi_dialogs_main_factiondebug_resource_rate_tooltip"] call _fnc_globalRow;
        ["STR_antistasi_dialogs_main_factiondebug_vehicle_cost", str (_global get "vehicleCost")] call _fnc_globalRow;
        ["STR_antistasi_dialogs_main_factiondebug_enemy_mul", format ["%1x", (_global get "enemyMul") toFixed 1]] call _fnc_globalRow;
        ["STR_antistasi_dialogs_main_factiondebug_attack_mul", format ["%1x", (_global get "attackMul") toFixed 1]] call _fnc_globalRow;
        ["STR_antistasi_dialogs_main_factiondebug_invader_mul", format ["%1x", (_global get "invaderMul") toFixed 1]] call _fnc_globalRow;
        ["STR_antistasi_dialogs_main_factiondebug_punishment_buff", (_global get "punishmentDefBuff") toFixed 2, "STR_antistasi_dialogs_main_factiondebug_punishment_buff_tooltip"] call _fnc_globalRow;
        ["STR_antistasi_dialogs_main_factiondebug_big_attack", (_global get "bigAttack") call _fnc_yesNo] call _fnc_globalRow;

        // The rows never change, so update the texts in place to keep the scroll position between refreshes
        if ((lnbSize _list) # 0 != count _rows) then {
            lnbClear _list;
            {
                _x params ["_label", "", "", "_tooltip", "_isSection"];
                private _index = _list lnbAddRow ["", "", ""];
                if (_tooltip != "") then { _list lnbSetTooltip [[_index, 0], _tooltip] };
                if (_isSection) then { _list lnbSetColor [[_index, 0], A3A_COLOR_FACTIONDEBUG_SECTION_SQF] };
            } forEach _rows;
        };
        {
            _x params ["_label", "_occText", "_invText"];
            _list lnbSetText [[_forEachIndex, 0], _label];
            _list lnbSetText [[_forEachIndex, 1], _occText];
            _list lnbSetText [[_forEachIndex, 2], _invText];
        } forEach _rows;

        _status ctrlSetText localize "STR_antistasi_dialogs_main_factiondebug_status";
    };

    default {
        Error_1("Factions tab mode does not exist: %1", _mode);
    };
};
