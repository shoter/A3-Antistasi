/*
Maintainer: Shoter
    Terminal cleanup of an air taxi, called exactly once per request.
    Refunds the fare and the pilot's HR when the trip did not happen through no fault of the passenger,
    refunds the HR when the pilot made it home (A3A_airTaxiRefundHR), and puts the helicopter
    back into the garage with its live state when it is still in one piece.

    Outcomes:
        completed                                   trip done, helicopter back at base
        no_spawn, hostile_lz, landing_failed,
        no_show, stuck, player_lost                 trip did not happen, fare and HR refunded
        destroyed                                   shot down, nothing refunded, garage entry lost

Arguments:
    <OBJECT> Requesting player (may be objNull if disconnected)
    <STRING> Requesting player UID
    <OBJECT> Helicopter (may be objNull or dead)
    <GROUP> Crew group
    <NUMBER> Garage vehicle UID
    <ARRAY> Garage entry copied at request time
    <NUMBER> Fare paid
    <NUMBER> HR paid
    <STRING> Outcome

Return Value:
    <nil>

Scope: Server
Environment: Any
Public: No
Dependencies:
    A3A_airTaxiActive, HR_GRG_Users, HR_GRG_fnc_getState

Example:
    [_player, _uid, _heli, _crewGroup, _vehUID, _entry, _money, _hr, "completed"] call A3A_fnc_airTaxiFinish;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [
    ["_player", objNull, [objNull]],
    ["_uid", "", [""]],
    ["_heli", objNull, [objNull]],
    ["_crewGroup", grpNull, [grpNull]],
    ["_vehUID", -1, [0]],
    ["_entry", [], [[]]],
    ["_money", 0, [0]],
    ["_hr", 0, [0]],
    ["_outcome", "completed", [""]]
];
if (!isServer) exitWith { Error("Called on a client, server only") };

// Bookkeeping
if (!isNull _heli) then {
    private _pad = _heli getVariable ["LandingPad", objNull];
    if (!isNull _pad) then { deleteVehicle _pad };
    _heli setVariable ["LandingPad", nil, true];
};
A3A_airTaxiActive deleteAt _uid;
if (!isNull _player) then { _player setVariable ["A3A_airTaxi", nil, true] };

// Helicopter back into the garage when it still exists (and nobody is still sitting in it), or never left it
private _heliBack = isNull _heli || { alive _heli && { ((crew _heli) - (units _crewGroup)) isEqualTo [] } };
private _sourceIndex = -1;
if (_heliBack && { !isNull _heli }) then {
    _entry set [3, ""];
    _entry set [4, [_heli] call HR_GRG_fnc_getState];
    _entry set [6, [_heli] call BIS_fnc_getVehicleCustomization];
    _sourceIndex = [[_heli] call HR_GRG_fnc_isAmmoSource, [_heli] call HR_GRG_fnc_isFuelSource, [_heli] call HR_GRG_fnc_isRepairSource] find true;
    { deleteVehicle _x } forEach units _crewGroup;     // crew first, so the heli never fires an empty GetOut
    deleteVehicle _heli;
};
if (_heliBack && { _entry isNotEqualTo [] }) then {
    private _recipients = +HR_GRG_Users;
    _recipients pushBackUnique 2;
    ["insert", _vehUID, _entry, _sourceIndex] remoteExecCall ["A3A_fnc_airTaxiGarageSync", _recipients];
};
if (!isNull _crewGroup && { units _crewGroup isEqualTo [] }) then { deleteGroup _crewGroup };

// Refunds
private _refund = _outcome in ["no_spawn", "hostile_lz", "landing_failed", "no_show", "stuck", "player_lost"];
private _refundHR = _refund || { _outcome == "completed" && _heliBack && A3A_airTaxiRefundHR };
if (_refund) then {
    if (!isNull _player) then {
        [_money, _player] call A3A_fnc_resourcesPlayer;
    } else {
        Info_2("Air taxi fare $%1 not refunded, player %2 is gone", _money, _uid);
    };
};
if (_refundHR) then { [_hr, 0, true] spawn A3A_fnc_resourcesFIA };

// Final status for the passenger
if (!isNull _player) then {
    private _key = switch (true) do {
        case (_heliBack && _refund): { "completed_refund" };
        case (_heliBack): { "completed" };
        case (_refund): { "lost_refund" };
        default { "" };
    };
    if (_key != "") then { ["STR_A3A_fn_logistics_airTaxi_" + _key] remoteExecCall ["A3A_fnc_airTaxiHint", _player] };
};

Info_5("Air taxi for %1 finished: %2, helicopter back %3, fare refunded %4, HR refunded %5", _uid, _outcome, _heliBack, _refund, _refundHR);
