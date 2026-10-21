/*
Maintainer: Shoter
    Orders an AI of the player's group to scrap or retrieve the nearest wreck, from the AI Management tab.
    The AI claims the nearest wreck within 300 m that nobody else has claimed and that may be worked on
    (for retrieve: that the junkyard can repair), walks to it, kneels and works on it for as long as a player of its
    class would (A3A_fnc_scrapDuration). The ordering player gets the money, see A3A_fnc_scrapStrip.
    The AI gives up when it dies, goes down, gets in a vehicle, leaves the group, cannot reach the wreck within
    3 minutes, gets other orders (it stops short of the wreck) or the wreck is taken by someone else. Afterwards it
    returns to formation.

Arguments:
    <OBJECT> AI unit, local to this client (AI of the player's own group are)
    <STRING> "scrap" or "retrieve"

Return Value:
    <nil>

Scope: Clients, Local Arguments
Environment: Scheduled
Public: No
Dependencies: A3A_fnc_scrapCanStrip, A3A_fnc_scrapStrip, A3A_fnc_scrapDuration, A3A_fnc_canFight, HR_GRG_fnc_getCatIndex, medicAnims

Example:
    { [_x, "retrieve"] spawn A3A_fnc_scrapWorkAI } forEach _selectedUnits;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

#define SEARCH_RADIUS 300
#define TRAVEL_TIMEOUT 180

params [["_unit", objNull, [objNull]], ["_mode", "scrap", [""]]];
if (isNull _unit or {isPlayer _unit} or {!local _unit}) exitWith {};

private _titleStr = localize "STR_A3A_fn_junkyard_scrap_title";
private _name = name _unit;
if (!alive _unit or {!([_unit] call A3A_fnc_canFight)}) exitWith {};
if (!isNull objectParent _unit) exitWith { [_titleStr, format [localize "STR_A3A_fn_junkyard_ai_inVehicle", _name]] call A3A_fnc_customHint };
if (_unit getVariable ["A3A_scrapWorking", false]) exitWith { [_titleStr, format [localize "STR_A3A_fn_junkyard_ai_busy", _name]] call A3A_fnc_customHint };

// Nearest free wreck, claimed in one unscheduled step so several AI ordered at once spread over different wrecks
private _isRetrieve = _mode == "retrieve";
private _wreck = objNull;
isNil {
    private _candidates = nearestObjects [_unit, ["LandVehicle", "Air", "Ship"], SEARCH_RADIUS];
    private _index = _candidates findIf {
        private _claim = _x getVariable ["A3A_scrapClaimedBy", objNull];
        !alive _x
        and {isNull _claim or {!alive _claim} or {!(_claim getVariable ["A3A_scrapWorking", false])}}
        and {([_x, _unit] call A3A_fnc_scrapCanStrip) # 0}
        and {!_isRetrieve or {private _cat = [typeOf _x] call HR_GRG_fnc_getCatIndex; _cat >= 0 and _cat != 7}}
    };
    if (_index != -1) then {
        _wreck = _candidates # _index;
        _wreck setVariable ["A3A_scrapClaimedBy", _unit, true];
        _unit setVariable ["A3A_scrapWorking", true];
    };
};
if (isNull _wreck) exitWith { [_titleStr, format [localize "STR_A3A_fn_junkyard_ai_noWreck", _name, SEARCH_RADIUS]] call A3A_fnc_customHint };

private _wreckName = getText (configOf _wreck >> "displayName");
private _reach = 6 + ((boundingBoxReal _wreck) # 2);
private _group = group _unit;
[_titleStr, format [localize (["STR_A3A_fn_junkyard_ai_scrapGoing", "STR_A3A_fn_junkyard_ai_retrieveGoing"] select _isRetrieve),
    _name, _wreckName, round (_unit distance _wreck)]] call A3A_fnc_customHint;

private _fnc_canGoOn = {
    alive _unit and {[_unit] call A3A_fnc_canFight} and {isNull objectParent _unit} and {group _unit == _group}
    and {([_wreck, _unit] call A3A_fnc_scrapCanStrip) # 0}
};

// Walk to the wreck. Becoming ready away from it means the move failed or the player gave other orders.
_unit doMove getPosATL _wreck;
private _travelEnd = time + TRAVEL_TIMEOUT;
private _orderTime = time;
private _arrived = false;
waitUntil {
    sleep 1;
    _arrived = _unit distance _wreck < _reach;
    _arrived or {!(call _fnc_canGoOn)} or {time > _travelEnd} or {time > _orderTime + 3 and {unitReady _unit}};
};

// Work on it, with the medic animations on a loop until the work flag is cleared
private _done = false;
if (_arrived and {call _fnc_canGoOn}) then {
    doStop _unit;
    _unit playMoveNow selectRandom medicAnims;
    private _animEH = _unit addEventHandler ["AnimDone", {
        params ["_unit"];
        if (_unit getVariable ["A3A_scrapWorking", false]) then { _unit playMoveNow selectRandom medicAnims };
    }];
    private _workEnd = time + ([_unit] call A3A_fnc_scrapDuration);
    waitUntil {
        sleep 0.5;
        _done = time >= _workEnd;
        _done or {!(call _fnc_canGoOn)} or {_unit distance _wreck > _reach};
    };
    _unit removeEventHandler ["AnimDone", _animEH];
};

_unit setVariable ["A3A_scrapWorking", nil];
if (!isNull _wreck and {_wreck getVariable ["A3A_scrapClaimedBy", objNull] == _unit}) then { _wreck setVariable ["A3A_scrapClaimedBy", nil, true] };
if (alive _unit and {[_unit] call A3A_fnc_canFight} and {isNull objectParent _unit}) then {
    if (toLower animationState _unit in (medicAnims apply { toLower _x })) then { _unit playMoveNow "AinvPknlMstpSnonWnonDnon_medicEnd" };
    _unit doFollow leader _unit;
};

if (!_done) exitWith { [_titleStr, format [localize "STR_A3A_fn_junkyard_ai_gaveUp", _name, _wreckName]] call A3A_fnc_customHint };
[_wreck, player, _mode, _unit] remoteExecCall ["A3A_fnc_scrapStrip", 2];
