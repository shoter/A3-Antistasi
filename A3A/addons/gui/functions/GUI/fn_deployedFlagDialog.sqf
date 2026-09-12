/*
Maintainer: Shoter
    Handles the rally flag teleport confirmation dialog (A3A_DeployedFlagDialog), opened from the HQ flag.
    "onLoad" fills the info text with the distance, enemy presence at the flag, travel time, cost and the squad AI
    coming along, or with the reasons the teleport is not possible, and enables the Teleport button only when the
    trip is possible and the player can afford it. "accept" closes the dialog and starts the teleport.

Arguments:
    <STRING> Mode: "onLoad" or "accept"
    <ARRAY<ANY>> Unused [DEFAULT = []]

Return Value:
    <nil>

Scope: Clients
Environment: Scheduled for onLoad, Unscheduled for accept
Public: No
Dependencies:
    A3A_fnc_deployedFlagTeleportInfo, A3A_fnc_deployedFlagTeleport

Example:
    ["onLoad"] spawn A3A_GUI_fnc_deployedFlagDialog;
*/

#include "..\..\dialogues\ids.inc"
#include "..\..\dialogues\defines.hpp"
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_mode", "onLoad"], ["_params", []]];

// Plain functions rather than macros: a # inside a macro body is the preprocessor's stringify operator
private _fnc_warning = { "<t color='#FF5940'>" + _this + "</t>" };
private _fnc_good = { "<t color='#59B359'>" + _this + "</t>" };

private _display = findDisplay A3A_IDD_DEPLOYEDFLAGDIALOG;

switch (_mode) do
{
    case ("onLoad"):
    {
        private _infoText = _display displayCtrl A3A_IDC_DEPLOYEDFLAG_INFOTEXT;
        private _acceptButton = _display displayCtrl A3A_IDC_DEPLOYEDFLAG_ACCEPTBUTTON;

        ([] call A3A_fnc_deployedFlagTeleportInfo) params ["_destPos", "_distance", "_enemyPresent", "_cost", "_travelTime", "_squadCount", "_blockers"];
        private _canAfford = player getVariable ["moneyX", 0] >= _cost;

        private _lines = [];
        if (_blockers isEqualTo []) then {
            private _distanceStr = if (_distance >= 1000) then { format ["%1 km", (round (_distance / 100)) / 10] } else { format ["%1 m", round _distance] };
            private _timeStr = [[_travelTime] call A3A_fnc_secondsToTimeSpan, 0, 0, false, 2] call A3A_fnc_timeSpan_format;
            _lines pushBack format [localize "STR_antistasi_dialogs_deployed_flag_distance", _distanceStr];
            _lines pushBack ([
                (localize "STR_antistasi_dialogs_deployed_flag_enemies_no") call _fnc_good,
                (localize "STR_antistasi_dialogs_deployed_flag_enemies_yes") call _fnc_warning
            ] select _enemyPresent);
            _lines pushBack format [localize "STR_antistasi_dialogs_deployed_flag_time", _timeStr];
            _lines pushBack format [localize "STR_antistasi_dialogs_deployed_flag_cost", _cost];
            _lines pushBack format [localize "STR_antistasi_dialogs_deployed_flag_squad", _squadCount];
            _lines pushBack "";
            _lines pushBack localize (["STR_antistasi_dialogs_deployed_flag_cold", "STR_antistasi_dialogs_deployed_flag_hot"] select _enemyPresent);
            if (!_canAfford) then {
                _lines pushBack "";
                _lines pushBack ((localize "STR_antistasi_dialogs_main_fast_travel_noMoney") call _fnc_warning);
            };
        } else {
            _lines = _blockers apply { _x call _fnc_warning };
        };

        _infoText ctrlSetStructuredText parseText (_lines joinString "<br/>");
        _acceptButton ctrlEnable (_blockers isEqualTo [] && _canAfford);
    };

    case ("accept"):
    {
        closeDialog 0;
        [] spawn A3A_fnc_deployedFlagTeleport;
    };

    default
    {
        Error_1("Deployed flag dialog mode does not exist: %1", _mode);
    };
};
