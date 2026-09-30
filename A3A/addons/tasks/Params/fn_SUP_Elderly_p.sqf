/*
Maintainer: Shoter
    Parameter getter for the elderly supplies task.
    Picks a town within mission distance of HQ and a lone house just outside its edge,
    away from other towns, military sites and players.

Arguments: none

Return Value:
    <BOOL> false if no valid parameters could be generated, otherwise
    <ARRAY> [weight, [town marker, house object]]

Scope: Server
Environment: Any
Public: No
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

private _hqPos = markerPos respawnTeamPlayer;
private _players = allPlayers - entities "HeadlessClient_F";
private _military = markersX - citiesX;
private _cities = (citiesX - destroyedSites) inAreaArray [_hqPos, distanceMission, distanceMission];

private _city = "";
private _house = objNull;
while {isNull _house and _cities isNotEqualTo []} do {
    _city = _cities deleteAt floor random count _cities;
    private _cityPos = markerPos _city;
    private _citySize = markerSize _city # 0;
    private _nearCities = citiesX inAreaArray [_cityPos, 3000, 3000];
    private _nearMilitary = _military inAreaArray [_cityPos, 2500, 2500];

    private _fnc_inTown = {
        params ["_pos"];
        _nearCities findIf { _pos distance2d markerPos _x < (markerSize _x # 0) + 100 } != -1;
    };

    // Lived-in houses in a ring 150-700m outside the town edge
    private _candidates = nearestObjects [_cityPos, ["House"], _citySize + 700, true] select {
        alive _x
        and { _x distance2d _cityPos > _citySize + 150 }
        and { count (_x buildingPos -1) >= 2 }
        and { count (_x buildingPos -1) <= 16 }
        and { _x distance2d _hqPos > 500 }
        and { !([getPosATL _x] call _fnc_inTown) }
        and { _nearMilitary inAreaArray [getPosATL _x, 500, 500] isEqualTo [] }
        and { _players inAreaArray [getPosATL _x, 300, 300] isEqualTo [] }
    };
    if (_candidates isNotEqualTo []) then { _house = selectRandom _candidates };
};

if (isNull _house) exitWith {
    Debug("No lone house found outside any town near HQ");
    false;
};

[1, [_city, _house]];
