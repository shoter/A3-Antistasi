/*
Maintainer: Shoter
    Client side of scrapping or retrieving a wreck, started from the action menu. The player kneels and works on the
    wreck (5-15 seconds for engineers, 30-60 for everyone else, see A3A_fnc_scrapDuration) with a progress bar at the
    bottom of the screen. Working stops when the
    player cancels it from the action menu, moves away, gets in a vehicle, can no longer fight or the wreck may no
    longer be worked on (see A3A_fnc_scrapCanStrip). When it completes, the server pays out and removes the wreck.

Arguments:
    <OBJECT> Wreck (dead vehicle)
    <STRING> "scrap" (full scrap pay, wreck gone for good) or "retrieve" (half the scrap pay, vehicle goes to the junkyard repair shop)

Return Value:
    <nil>

Scope: Clients
Environment: Scheduled
Public: No
Dependencies: A3A_fnc_scrapCanStrip, A3A_fnc_scrapStrip, A3A_fnc_canFight, A3A_GUI_fnc_progressBar, A3A_fnc_scrapDuration, medicAnims

Example:
    [cursorObject, "retrieve"] spawn A3A_fnc_scrapWork;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_wreck", objNull, [objNull]], ["_mode", "scrap", [""]]];
if (!hasInterface or isNull _wreck) exitWith {};
if (player getVariable ["A3A_scrapWorking", false]) exitWith {};

private _isRetrieve = _mode == "retrieve";
private _titleStr = localize "STR_A3A_fn_junkyard_scrap_title";
private _displayName = getText (configOf _wreck >> "displayName");
private _caption = format [localize (["STR_A3A_fn_junkyard_scrap_progress", "STR_A3A_fn_junkyard_retrieve_progress"] select _isRetrieve), _displayName];

player setVariable ["A3A_scrapWorking", true];
player setVariable ["A3A_scrapCancel", false];
private _cancelAction = player addAction [
    localize "STR_A3A_fn_junkyard_scrap_cancel",
    { (_this # 1) setVariable ["A3A_scrapCancel", true] },
    nil, 6, true, true, "", "_this == _target"
];

// Kneeling medic animations on a loop until the work flag is cleared
player playMoveNow selectRandom medicAnims;
private _animEH = player addEventHandler ["AnimDone", {
    params ["_unit"];
    if (_unit getVariable ["A3A_scrapWorking", false]) then { _unit playMoveNow selectRandom medicAnims };
}];

["show", [_caption]] call A3A_GUI_fnc_progressBar;
private _start = time;
private _duration = [player] call A3A_fnc_scrapDuration;
private _result = "";
waitUntil {
    sleep 0.1;
    private _elapsed = time - _start;
    ["update", [_elapsed / _duration, format ["%1 (%2 s)", _caption, ceil ((_duration - _elapsed) max 0)]]] call A3A_GUI_fnc_progressBar;
    _result = call {
        if (player getVariable ["A3A_scrapCancel", false]) exitWith { "STR_A3A_fn_junkyard_scrap_cancelled" };
        if (!([player] call A3A_fnc_canFight) or {!isNull objectParent player}) exitWith { "STR_A3A_fn_junkyard_scrap_cancelled" };
        ([_wreck, player] call A3A_fnc_scrapCanStrip) params ["_allowed", "_reason"];
        if (!_allowed) exitWith { _reason };
        if (player distance _wreck > 6 + ((boundingBoxReal _wreck) # 2)) exitWith { "STR_A3A_fn_junkyard_scrap_tooFar" };
        if (_elapsed >= _duration) exitWith { "done" };
        "";
    };
    _result != "";
};

player removeAction _cancelAction;
player removeEventHandler ["AnimDone", _animEH];
player setVariable ["A3A_scrapWorking", nil];
player setVariable ["A3A_scrapCancel", nil];
["hide"] call A3A_GUI_fnc_progressBar;
// Get up from the medic animation, unless something else (unconscious, vehicle) has taken over
if (([player] call A3A_fnc_canFight) and {isNull objectParent player} and {toLower animationState player in (medicAnims apply { toLower _x })}) then {
    player playMoveNow "AinvPknlMstpSnonWnonDnon_medicEnd";
};

if (_result != "done") exitWith { [_titleStr, localize _result] call A3A_fnc_customHint };
[_wreck, player, _mode] remoteExecCall ["A3A_fnc_scrapStrip", 2];
