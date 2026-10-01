/*
Maintainer: Shoter
    Handles the bribe money dialog of the buying intel mission (A3A_BuyIntelDialog), opened from the money truck.
    The truck is passed in A3A_GUI_buyIntelTruck by the truck action. The amount can never go above what the
    player has or what the bribe still needs; it starts at the most the player can load.
    "load" closes the dialog and sends the amount to the server (A3A_tasks_fnc_LOG_BuyIntel_deposit).

Arguments:
    <STRING> Mode: "onLoad", "sliderChanged", "editBoxChanged", "add" or "load"
    <ARRAY<ANY>> For "add": [<SCALAR> euros to add, negative to subtract] [DEFAULT = []]

Return Value:
    <nil>

Scope: Clients
Environment: Scheduled for the dialog events, Unscheduled for load
Public: No
Dependencies:
    A3A_tasks_fnc_LOG_BuyIntel_deposit

Example:
    ["onLoad"] spawn A3A_GUI_fnc_buyIntelDialog;
*/

#include "..\..\dialogues\ids.inc"
#include "..\..\dialogues\defines.hpp"
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_mode", "onLoad"], ["_params", []]];

private _display = findDisplay A3A_IDD_BUYINTELDIALOG;
private _truck = missionNamespace getVariable ["A3A_GUI_buyIntelTruck", objNull];
private _editBox = _display displayCtrl A3A_IDC_BUYINTEL_EDITBOX;
private _slider = _display displayCtrl A3A_IDC_BUYINTEL_SLIDER;

// Most the player can load right now
private _cost = _truck getVariable ["A3A_buyIntelCost", 1000];
private _loaded = _truck getVariable ["A3A_buyIntelMoney", 0];
private _money = player getVariable ["moneyX", 0];
private _max = 0 max ((_cost - _loaded) min _money);

private _fnc_setAmount = {
    private _value = 0 max (floor _this) min _max;
    _editBox ctrlSetText str _value;
    _slider sliderSetPosition _value;
};

switch (_mode) do
{
    case ("onLoad"):
    {
        if (!alive _truck) exitWith { closeDialog 0 };
        private _infoText = _display displayCtrl A3A_IDC_BUYINTEL_INFOTEXT;
        _infoText ctrlSetStructuredText parseText format [localize "STR_antistasi_dialogs_buy_intel_info", _loaded, _cost, _cost - _loaded, _money];

        _slider sliderSetRange [0, _max max 1];
        _slider sliderSetSpeed [10, 100];
        _slider ctrlEnable (_max > 0);
        _editBox ctrlEnable (_max > 0);
        (_display displayCtrl A3A_IDC_BUYINTEL_LOADBUTTON) ctrlEnable (_max > 0);
        _max call _fnc_setAmount;
    };

    case ("sliderChanged"):
    {
        (sliderPosition _slider) call _fnc_setAmount;
    };

    case ("editBoxChanged"):
    {
        (parseNumber ctrlText _editBox) call _fnc_setAmount;      // also strips non-numeric characters
    };

    case ("add"):
    {
        _params params [["_change", 0, [0]]];
        ((parseNumber ctrlText _editBox) + _change) call _fnc_setAmount;
    };

    case ("load"):
    {
        private _amount = 0 max (floor parseNumber ctrlText _editBox) min _max;
        closeDialog 0;
        if (_amount > 0) then {
            [player, _truck, _amount] remoteExecCall ["A3A_tasks_fnc_LOG_BuyIntel_deposit", 2];
        };
    };

    default
    {
        Error_1("Buy intel dialog mode does not exist: %1", _mode);
    };
};
