/*
Maintainer: Shoter
    Quotes an air taxi trip: money, HR, distance and an estimated time until arrival.
    Single source of truth for the client preview and the server charge.
    Money handling is the caller's job.

Arguments:
    <POSITION> Pickup position
    <POSITION> Destination position
    <STRING> Helicopter classname, used for the time estimate [DEFAULT = ""]

Return Value:
    <ARRAY> [<NUMBER> money, <NUMBER> HR, <NUMBER> distance in metres, <NUMBER> estimated seconds until arrival]

Scope: Any
Environment: Any
Public: Yes
Dependencies:
    A3A_airTaxiFareBase, A3A_airTaxiFarePerKm, A3A_airTaxiHR, A3A_airTaxiBoardTime

Example:
    [getPosATL player, markerPos "outpost_1", "C_Heli_Light_01_civil_F"] call A3A_fnc_airTaxiFare params ["_money", "_hr", "_distance", "_eta"];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_pickupPos", [0,0,0], [[]]], ["_destPos", [0,0,0], [[]]], ["_class", "", [""]]];

private _distance = _pickupPos distance2D _destPos;
private _money = ceil (A3A_airTaxiFareBase + A3A_airTaxiFarePerKm * _distance / 1000);
private _hr = A3A_airTaxiHR;

private _eta = 0;
if (_class != "") then {
    private _originPos = markerPos ([_pickupPos] call A3A_fnc_airTaxiOrigin);
    private _cruise = (getNumber (configFile >> "CfgVehicles" >> _class >> "maxSpeed") / 3.6 * 0.8) max 20;     // m/s
    _eta = round (((_originPos distance2D _pickupPos) + _distance) / _cruise + A3A_airTaxiBoardTime);
};

[_money, _hr, _distance, _eta]
