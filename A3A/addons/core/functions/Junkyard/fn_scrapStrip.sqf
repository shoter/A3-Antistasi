/*
Maintainer: Shoter
    Server side of scrapping or retrieving a wreck, called when a player (A3A_fnc_scrapWork) or an AI of the
    player's group (A3A_fnc_scrapWorkAI) finishes working on it. The player is paid either way.
    Re-checks everything, marks the wreck as taken, pays the player and deletes the wreck at once.
    Scrap pays a share of the junkyard price of the vehicle class (at least A3A_scrapMinPay) and the vehicle is gone for good.
    Retrieve pays A3A_scrapRetrieveShare of that and sends the vehicle class to the junkyard repair shop,
    so the faction can buy it back repaired later. Vehicles the junkyard cannot sell can only be scrapped.
    Must run unscheduled (remoteExecCall) so the check and the taken flag cannot interleave with another request.

Arguments:
    <OBJECT> Wreck (dead vehicle)
    <OBJECT> Player who gets paid
    <STRING> "scrap" or "retrieve" [DEFAULT = "scrap"]
    <OBJECT> Unit that did the work, the player or an AI of their group [DEFAULT = the player]

Return Value:
    <nil>

Scope: Server
Environment: Unscheduled
Public: No
Dependencies: A3A_fnc_scrapCanStrip, A3A_fnc_junkyardPrice, A3A_fnc_resourcesPlayer, A3A_fnc_junkyardRepairAdd

Example:
    [_wreck, player, "retrieve"] remoteExecCall ["A3A_fnc_scrapStrip", 2];
    [_wreck, player, "scrap", _aiEngineer] remoteExecCall ["A3A_fnc_scrapStrip", 2];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

// Share of the junkyard price paid out for a scrapped wreck, tune here
#define SCRAP_SHARE_MIN 0.005
#define SCRAP_SHARE_MAX 0.015

if !(isServer) exitWith { Error("Attempted to call server function as non-server") };
params [["_wreck", objNull, [objNull]], ["_player", objNull, [objNull]], ["_mode", "scrap", [""]], ["_worker", objNull, [objNull]]];
if (isNull _wreck or isNull _player) exitWith {};
if (isNull _worker) then { _worker = _player };
private _isRetrieve = _mode == "retrieve";

private _titleStr = localize "STR_A3A_fn_junkyard_scrap_title";
private _fnc_fail = {
    params ["_reason"];
    [_titleStr, localize _reason] remoteExec ["A3A_fnc_customHint", _player];
    Info_4("Scrapyard: %1 could not %2 %3 (%4)", name _player, _mode, typeOf _wreck, _reason);
};

if (!isPlayer _player or {side group _player != teamPlayer}) exitWith {
    Info_2("Scrapyard: rejected request from %1 for %2", name _player, typeOf _wreck);
};
if (_worker != _player and {group _worker != group _player or isPlayer _worker}) exitWith {
    Info_3("Scrapyard: rejected request from %1 for %2, %3 is not in their group", name _player, typeOf _wreck, name _worker);
};
if (!alive _worker or {!isNull objectParent _worker}) exitWith { ["STR_A3A_fn_junkyard_scrap_cancelled"] call _fnc_fail };
// Bounding radius so large wrecks measured from their centre still pass, with some margin over the client conditions
if (_worker distance _wreck > 10 + ((boundingBoxReal _wreck) # 2)) exitWith { ["STR_A3A_fn_junkyard_scrap_tooFar"] call _fnc_fail };

([_wreck, _worker] call A3A_fnc_scrapCanStrip) params ["_allowed", "_reason"];
if (!_allowed) exitWith { [_reason] call _fnc_fail };

private _class = typeOf _wreck;
private _price = [_class] call A3A_fnc_junkyardPrice;

// Retrieve: the repair shop takes it first, so a vehicle it refuses is not paid for
private _repair = [];
if (_isRetrieve) then { _repair = [_class, _price] call A3A_fnc_junkyardRepairAdd };
if (_isRetrieve and {_repair isEqualTo []}) exitWith { ["STR_A3A_fn_junkyard_scrap_notRepairable"] call _fnc_fail };

// Flag first. This runs unscheduled, so no other request can get past the check above for this wreck.
_wreck setVariable ["A3A_scrapStripped", true, true];

private _pay = round ((_price * (SCRAP_SHARE_MIN + random (SCRAP_SHARE_MAX - SCRAP_SHARE_MIN))) max A3A_scrapMinPay);
if (_isRetrieve) then { _pay = round (_pay * A3A_scrapRetrieveShare) };
[_pay, _player] call A3A_fnc_resourcesPlayer;
[[_player] call A3A_fnc_playerStats_getUID, [["vehiclesScrapped", 1], ["scrapMoney", _pay]]] call A3A_fnc_playerStats_add;

// The wreck disappears now. Living units still inside are moved out; dead crew are deleted with the seats freed,
// the same way the garbage cleaner does it. Both run where the unit is local, so the wreck waits for them a few seconds.
if (crew _wreck isEqualTo []) then {
    deleteVehicle _wreck;
} else {
    {
        if (alive _x) then { [_x] remoteExec ["moveOut", _x] } else { [_wreck, _x] remoteExec ["deleteVehicleCrew", _x] };
    } forEach crew _wreck;
    [_wreck] spawn {
        params ["_wreck"];
        private _timeout = time + 5;
        waitUntil { sleep 0.5; crew _wreck isEqualTo [] or time > _timeout };
        deleteVehicle _wreck;
    };
};

private _displayName = getText (configFile >> "CfgVehicles" >> _class >> "displayName");
private _text = if (_isRetrieve) then {
    private _repairTime = [(_repair#4) - (call A3A_fnc_junkyardClock), 1, 1, false, 2, false, true] call A3A_fnc_timeSpan_format;
    format [localize "STR_A3A_fn_junkyard_scrap_retrieved", _displayName, _pay, _repairTime]
} else {
    format [localize "STR_A3A_fn_junkyard_scrap_stripped", _displayName, _pay]
};
[_titleStr, _text] remoteExec ["A3A_fnc_customHint", _player];
Info_4("Scrapyard: %1 did %2 on %3 for %4 €", name _player, _mode, _class, _pay);
