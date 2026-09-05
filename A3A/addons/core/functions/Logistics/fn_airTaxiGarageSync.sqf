/*
Maintainer: Shoter
    Removes or re-inserts an air taxi helicopter entry in the garage pool.
    Run on the server and on every client with the garage dialog open (HR_GRG_Users),
    so their copies of HR_GRG_Vehicles stay in sync and the list refreshes.
    Mirrors the pool mutation and refresh done by HR_GRG_fnc_removeFromPool.

Arguments:
    <STRING> "remove" or "insert"
    <NUMBER> Garage vehicle UID
    <ARRAY> Garage entry to insert (ignored for "remove") [DEFAULT = []]
    <NUMBER> Source registry index for "insert": 0 ammo, 1 fuel, 2 repair, -1 none [DEFAULT = -1]

Return Value:
    <nil>

Scope: Any
Environment: Unscheduled
Public: No
Dependencies:
    HR_GRG_Vehicles, HR_GRG_Sources, HR_GRG_Cats

Example:
    private _recipients = +HR_GRG_Users; _recipients pushBackUnique 2;
    ["remove", _vehUID] remoteExecCall ["A3A_fnc_airTaxiGarageSync", _recipients];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_mode", "", [""]], ["_vehUID", -1, [0]], ["_entry", [], [[]]], ["_sourceIndex", -1, [0]]];
if (isNil "HR_GRG_Vehicles") exitWith {};       // client without an open garage dialog, nothing to sync

private _cat = HR_GRG_Vehicles # 3;      // helicopter category, see garage/CfgDefines.inc

switch (_mode) do {
    case ("remove"): {
        _cat deleteAt _vehUID;
        {
            private _index = _x find _vehUID;
            if (_index != -1) exitWith {
                (HR_GRG_Sources # _forEachIndex) deleteAt _index;
                if (isServer) then { [_forEachIndex] call HR_GRG_fnc_declairSources };
            };
        } forEach HR_GRG_Sources;
    };

    case ("insert"): {
        if (_entry isEqualTo []) exitWith {};
        _cat set [_vehUID, _entry];
        if (_sourceIndex > -1) then {
            (HR_GRG_Sources # _sourceIndex) pushBackUnique _vehUID;
            if (isServer) then { [_sourceIndex] call HR_GRG_fnc_declairSources };
        };
    };

    default { Error_1("Unknown air taxi garage sync mode %1", _mode) };
};

// Refresh the garage dialog if this machine has one open (controls of a closed dialog are null and disabled)
if (!isNull player && { !isNil "HR_GRG_Cats" }) then {
    call HR_GRG_fnc_updateVehicleCount;
    {
        if (ctrlEnabled _x) then { [_x, _forEachIndex] call HR_GRG_fnc_reloadCategory };
    } forEach HR_GRG_Cats;
};
