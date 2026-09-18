/*
Maintainer: Shoter
    Handles the loot crate delivery order dialog (A3A_LootDeliveryDialog), opened from the Battle Command menu.
    "onLoad" remembers where the player stands (the crate goes there, even if the player moves on), lists who
    pays and what the pickup and the plane cost, and enables each order button only when that option is
    available and affordable. "order" closes the dialog and sends the order to the server.

Arguments:
    <STRING> Mode: "onLoad" or "order"
    <ARRAY<ANY>> For "order": [<STRING> "pickup" or "plane"] [DEFAULT = []]

Return Value:
    <nil>

Scope: Clients
Environment: Scheduled for onLoad, Unscheduled for order
Public: No
Dependencies:
    A3A_fnc_lootDeliveryInfo, A3A_fnc_lootDeliveryRequest

Example:
    ["onLoad"] spawn A3A_GUI_fnc_lootDeliveryDialog;
*/

#include "..\..\dialogues\ids.inc"
#include "..\..\dialogues\defines.hpp"
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_mode", "onLoad"], ["_params", []]];

// Plain functions rather than macros: a # inside a macro body is the preprocessor's stringify operator
private _fnc_warning = { "<t color='#FF5940'>" + _this + "</t>" };
private _fnc_header = { "<t size='1.2'>" + _this + "</t>" };

private _display = findDisplay A3A_IDD_LOOTDELIVERYDIALOG;

switch (_mode) do
{
    case ("onLoad"):
    {
        private _infoText = _display displayCtrl A3A_IDC_LOOTDELIVERY_INFOTEXT;
        private _pickupButton = _display displayCtrl A3A_IDC_LOOTDELIVERY_PICKUPBUTTON;
        private _planeButton = _display displayCtrl A3A_IDC_LOOTDELIVERY_PLANEBUTTON;

        // The crate goes to where the player stands right now
        private _dropPos = getPosATL player;
        _display setVariable ["dropPos", _dropPos];

        ([player, _dropPos] call A3A_fnc_lootDeliveryInfo) params ["_fee", "_factionPays", "_funds", "_hr", "_blockers", "_pickup", "_plane"];
        _pickup params ["_pickupClass", "_pickupDeposit", "_pickupBlockers"];
        _plane params ["_planeClass", "_planeDeposit", "_planeBlockers", "_airport"];

        private _lines = [];
        _lines pushBack format [
            localize (["STR_antistasi_dialogs_loot_delivery_payer_personal", "STR_antistasi_dialogs_loot_delivery_payer_faction"] select _factionPays),
            _funds, _hr
        ];
        _lines pushBack format [localize "STR_antistasi_dialogs_loot_delivery_position", mapGridPosition _dropPos];

        private _fnc_option = {
            params ["_titleKey", "_class", "_deposit", "_optionBlockers", "_noteKey", "_noteArgs"];
            _lines pushBack "";
            private _name = if (_class == "") then { "" } else { getText (configFile >> "CfgVehicles" >> _class >> "displayName") };
            _lines pushBack ((format [localize _titleKey, _name]) call _fnc_header);
            if ((_optionBlockers arrayIntersect ["no_vehicle", "no_airport"]) isEqualTo []) then {
                _lines pushBack format [localize "STR_antistasi_dialogs_loot_delivery_cost", _fee + _deposit, _fee, _deposit];
                _lines pushBack format [localize "STR_antistasi_dialogs_loot_delivery_refund", _deposit];
                _lines pushBack format ([localize _noteKey] + _noteArgs);
            };
            {
                _lines pushBack ((localize ("STR_A3A_fn_logistics_lootDelivery_blk_" + _x)) call _fnc_warning);
            } forEach _optionBlockers;
        };

        if (_blockers isEqualTo []) then {
            ["STR_antistasi_dialogs_loot_delivery_pickup_title", _pickupClass, _pickupDeposit, _pickupBlockers,
                "STR_antistasi_dialogs_loot_delivery_pickup_note", []] call _fnc_option;
            private _airportName = if (_airport == "") then { "" } else { [_airport] call A3A_fnc_localizar };
            ["STR_antistasi_dialogs_loot_delivery_plane_title", _planeClass, _planeDeposit, _planeBlockers,
                "STR_antistasi_dialogs_loot_delivery_plane_note", [_airportName]] call _fnc_option;
        } else {
            _lines pushBack "";
            { _lines pushBack ((localize ("STR_A3A_fn_logistics_lootDelivery_blk_" + _x)) call _fnc_warning) } forEach _blockers;
        };

        _infoText ctrlSetStructuredText parseText (_lines joinString "<br/>");
        _pickupButton ctrlEnable (_blockers isEqualTo [] && { _pickupBlockers isEqualTo [] });
        _planeButton ctrlEnable (_blockers isEqualTo [] && { _planeBlockers isEqualTo [] });
    };

    case ("order"):
    {
        _params params [["_type", "pickup", [""]]];
        private _dropPos = _display getVariable ["dropPos", getPosATL player];
        closeDialog 0;
        [player, _type, _dropPos, clientOwner] remoteExecCall ["A3A_fnc_lootDeliveryRequest", 2];
    };

    default
    {
        Error_1("Loot delivery dialog mode does not exist: %1", _mode);
    };
};
