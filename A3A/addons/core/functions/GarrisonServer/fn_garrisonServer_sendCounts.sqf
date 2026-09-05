/*
Maintainer: Shoter
    Server-side function that sends troop, vehicle and static counts of every rebel garrison
    to the Garrisons tab of the requesting client. Only counts leave the server, never the garrison hashmaps.

Arguments:
    <NUMBER> Client owner ID to send the counts to.

Return Value:
    Nothing

Scope: Server, Local Arguments, Global Effect
Environment: Unscheduled
Public: No
Dependencies:
    <HASHMAP> A3A_garrison
    <OBJECT> sidesX
    <ARRAY> citiesX

Example:
    [clientOwner] remoteExecCall ["A3A_fnc_garrisonServer_sendCounts", 2];

License: APL-ND

*/

#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_client", -1, [0]]];

Trace_1("Called with params %1", _this);

if (_client < 0) exitWith { Error("No client to send garrison counts to") };

// [marker, troops, vehicles, statics, ammoPct, resupplying] per rebel site. Cities are covered by the Towns tab.
// ammoPct is the mean fill of the static weapons in percent, -1 when the site has none.
private _counts = [];
{
    private _marker = _x;
    private _garrison = _y;
    if (_marker in citiesX) then { continue };
    if (_marker != "Synd_HQ" && {sidesX getVariable [_marker, sideUnknown] != teamPlayer}) then { continue };

    private _vehicles = _garrison getOrDefault ["vehicles", []];
    private _statics = { (_x # 0) isKindOf "StaticWeapon" } count _vehicles;

    private _ammoPct = -1;
    private _staticsInfo = [_marker, true] call A3A_fnc_garrisonServer_ammoInfo;
    if (_staticsInfo isNotEqualTo []) then {
        private _sum = 0;
        { _sum = _sum + (_x # 2) } forEach _staticsInfo;
        _ammoPct = round (100 * _sum / count _staticsInfo);
    };
    private _resupplying = _marker in A3A_garrisonResupplyActive;

    _counts pushBack [_marker, count (_garrison getOrDefault ["troops", []]), (count _vehicles) - _statics, _statics, _ammoPct, _resupplying];
} forEach A3A_garrison;

["countsReceived", [_counts]] remoteExecCall ["A3A_GUI_fnc_garrisonsTab", _client];
