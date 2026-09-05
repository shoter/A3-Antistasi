/*
Maintainer: Shoter
    Server side of stripping a wreck for scrap, called when a player finishes the hold action.
    Re-checks everything, marks the wreck as stripped, pays the player a share of the junkyard price of the vehicle
    class (at least A3A_scrapMinPay) and hands the wreck to the garbage cleaner.
    Must run unscheduled (remoteExecCall) so the check and the stripped flag cannot interleave with another request.

Arguments:
    <OBJECT> Wreck (dead vehicle)
    <OBJECT> Player stripping it

Return Value:
    <nil>

Scope: Server
Environment: Unscheduled
Public: No
Dependencies: A3A_fnc_scrapCanStrip, A3A_fnc_junkyardPrice, A3A_fnc_resourcesPlayer, A3A_fnc_postmortem

Example:
    [_wreck, player] remoteExecCall ["A3A_fnc_scrapStrip", 2];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

// Share of the junkyard price paid out for a wreck, tune here
#define SCRAP_SHARE_MIN 0.01
#define SCRAP_SHARE_MAX 0.03

if !(isServer) exitWith { Error("Attempted to call server function as non-server") };
params [["_wreck", objNull, [objNull]], ["_player", objNull, [objNull]]];
if (isNull _wreck or isNull _player) exitWith {};

private _titleStr = localize "STR_A3A_fn_junkyard_scrap_title";
private _fnc_fail = {
    params ["_reason"];
    [_titleStr, localize _reason] remoteExec ["A3A_fnc_customHint", _player];
    Info_3("Scrapyard: %1 could not strip %2 (%3)", name _player, typeOf _wreck, _reason);
};

if (!isPlayer _player or {!alive _player} or {side group _player != teamPlayer} or {!isNull objectParent _player}) exitWith {
    Info_2("Scrapyard: rejected strip request from %1 for %2", name _player, typeOf _wreck);
};
// Bounding radius so large wrecks measured from their centre still pass, with some margin over the client conditions
if (_player distance _wreck > 10 + ((boundingBoxReal _wreck) # 2)) exitWith { ["STR_A3A_fn_junkyard_scrap_tooFar"] call _fnc_fail };

([_wreck, _player] call A3A_fnc_scrapCanStrip) params ["_allowed", "_reason"];
if (!_allowed) exitWith { [_reason] call _fnc_fail };

// Flag first. This runs unscheduled, so no other request can get past the check above for this wreck.
_wreck setVariable ["A3A_scrapStripped", true, true];

private _class = typeOf _wreck;
private _price = [_class] call A3A_fnc_junkyardPrice;
private _pay = round ((_price * (SCRAP_SHARE_MIN + random (SCRAP_SHARE_MAX - SCRAP_SHARE_MIN))) max A3A_scrapMinPay);
[_pay, _player] call A3A_fnc_resourcesPlayer;

// Hand the husk to the garbage cleaner: front of the queue with its proximity bumps used up, so the next pass deletes it
_wreck setVariable ["A3A_gcBumps", A3A_gcMaxBumps];
[_wreck, true] call A3A_fnc_postmortem;

private _displayName = getText (configFile >> "CfgVehicles" >> _class >> "displayName");
[_titleStr, format [localize "STR_A3A_fn_junkyard_scrap_stripped", _displayName, _pay]] remoteExec ["A3A_fnc_customHint", _player];
Info_3("Scrapyard: %1 stripped %2 for %3 PLN", name _player, _class, _pay);
