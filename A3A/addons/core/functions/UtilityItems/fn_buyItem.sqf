/*
Author: [Killerswin2, Håkon]
    Tries to purchase a buyable item, using either the garage placer or a simple placer as appropriate. Damage for the object is disabled.
Arguments:
0.  <object>    Unit that will be buying the item
1.  <string>    Item classname

Scope: Clients
Environment: Unscheduled
Public: yes
Dependencies:

Example:
    [player, _fuelDrum # 0] call A3A_fnc_buyItem
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params ["_unit", "_itemClass"];
private _titleStr = localize "STR_A3A_Utility_Items_Purchase_Title";

if (isNull _unit) exitwith { Error("Unit is null") };
if (!isClass (configFile/"CfgVehicles"/_itemClass)) exitwith { Error_1("Class %1 does not exist", _itemClass) };
if !(_itemClass in A3A_utilityItemHM) exitWith { Error_1("Class %1 is not a buyable item", _itemClass) };

private _fnc_placed = {
    params ["_item", "_unit", "_price", "_flags"];
    if (isNull _item) exitWith {};          // placement cancelled

    // Commander and sub-commanders pay from the faction funds, everyone else from their own pocket
    private _useFactionFunds = [_unit] call A3A_fnc_isCommandStaff;
    private _funds = if (_useFactionFunds) then { server getVariable ["resourcesFIA", 0] } else { _unit getVariable ["moneyX", 0] };
    if (_funds < _price) exitWith {
        [localize "STR_A3A_Utility_Items_Purchase_Title", localize "STR_A3A_Utility_Items_Insufficient_Funds"] call A3A_fnc_customHint;
        deleteVehicle _item;
    };

    if (_price > 0) then {
        if (_useFactionFunds) exitWith {
            [0, -_price] remoteExec ["A3A_fnc_resourcesFIA", 2];
            // The commander hears about purchases of sub-commanders
            if (_unit != theBoss) then {
                private _itemName = (A3A_utilityItemHM getOrDefault [typeOf _item, []]) param [2, ""];
                if (_itemName == "") then { _itemName = getText (configFile >> "CfgVehicles" >> typeOf _item >> "displayName") };
                [_unit, _itemName, _price, 0] remoteExecCall ["A3A_fnc_subCommanderSpent", 2];
            };
        };
        [-_price] call A3A_fnc_resourcesPlayer;     // uh, we're just assuming _unit == player here
    };

    _unit setVariable ["A3A_spawnItem_cooldown", time + 15];

    _item call A3A_fnc_initObject;
};


(A3A_utilityItemHM get _itemClass) params ["", "_price", "", "", "_flags"];

private _lastItemPurchase = _unit getVariable ["A3A_spawnItem_cooldown", 0];
if (_lastItemPurchase > time) exitwith {
    [_titleStr, format [localize "STR_A3A_Utility_Items_Last_Time_Purchase", ceil (_lastItemPurchase - time)]] call A3A_fnc_customHint;
};

if (("cmmdr" in _flags) && player isNotEqualTo theBoss) exitwith {
    [localize "STR_antistasi_dialogs_buy_item_custom_hint_header", localize "STR_antistasi_dialogs_buy_item_custom_hint_commander_only"] call A3A_fnc_customHint;
};

private _funds = if ([_unit] call A3A_fnc_isCommandStaff) then { server getVariable ["resourcesFIA", 0] } else { _unit getVariable ["moneyX", 0] };
if (_funds < _price) exitWith {
    [_titleStr, localize "STR_A3A_Utility_Items_Insufficient_Funds"] call A3A_fnc_customHint;
};

// Simple random placement
if !("place" in _flags) exitWith
{
    //spawn the Item
    private _position = (getPosATL _unit vectorAdd [3,0,0]) findEmptyPosition [1,50,_itemClass];
    if (_position isEqualTo []) then {_position = getPosATL _unit};
    private _item = _itemClass createVehicle _position;
    _item allowDamage false;            // what, permanent? TODO: make this an item flag?

    [_item, _unit, _price, _flags] call _fnc_placed;
};

// Manual placement
[_itemClass, _fnc_placed, {false}, [_unit, _price, _flags]] call HR_GRG_fnc_confirmPlacement;
