/*
Maintainer: Shoter
    Parameter getter for the buying intel task.
    Picks an enemy town within mission distance that has an outpost or airbase of the same side 1-6 km away,
    a roadside spot near the town centre for the officer's car, and a house next to it where the officer waits.

Arguments: none

Return Value:
    <BOOL> false if no valid parameters could be generated, otherwise
    <ARRAY> [weight, [town marker, house object, car position ATL, car direction, outpost marker]]

Scope: Server
Environment: Any
Public: No
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

private _hqPos = markerPos "Synd_HQ";
private _players = allPlayers - entities "HeadlessClient_F";
// Lived-in houses only: no military buildings, sheds, churches or ruins
private _badTypes = ["cargo", "mil_", "military", "barrack", "bunker", "tower", "hangar", "church", "chapel", "cathedral", "mosque", "shed", "garage", "fuel", "factory", "industrial", "tank", "pier", "hospital", "ruin", "castle", "wip"];

private _fnc_isHouse = {
    params ["_house"];
    if (!alive _house or isObjectHidden _house) exitWith {false};
    private _type = toLower typeOf _house;
    if (_badTypes findIf { _x in _type } != -1) exitWith {false};
    private _positions = (_house buildingPos -1) select { !surfaceIsWater _x };
    if (count _positions < 2 or count _positions > 30) exitWith {false};
    // The officer waits on the ground floor, so he can walk out to his car
    _positions findIf { _x # 2 < 1 } != -1;
};

private _cities = (citiesX inAreaArray [_hqPos, distanceMission, distanceMission]) - destroyedSites;
_cities = _cities select { sidesX getVariable _x in [Occupants, Invaders] } select { spawner getVariable _x != 0 };

private _place = [];
while { _place isEqualTo [] and _cities isNotEqualTo [] } do {
    private _city = _cities deleteAt floor random count _cities;
    private _side = sidesX getVariable _city;
    private _cityPos = markerPos _city;

    // Where the officer drives back to
    private _outposts = (outposts + airportsX) select { sidesX getVariable _x == _side }
        select { private _dist = markerPos _x distance2d _cityPos; _dist > 1000 and _dist < 6000 };
    if (_outposts isEqualTo []) then { continue };

    // Roads near the town centre: not a bridge, not a junction, no vehicles or players close
    private _roads = (_cityPos nearRoads 300) select { getPosATL _x # 2 < 0.5 }
        select { count roadsConnectedTo _x == 2 }
        select { _players inAreaArray [getPosATL _x, 500, 500] isEqualTo [] };
    private _tries = 20;
    while { _place isEqualTo [] and _roads isNotEqualTo [] and _tries > 0 } do {
        _tries = _tries - 1;
        private _road = _roads deleteAt floor random count _roads;
        private _start = getRoadInfo _road # 6;
        private _end = getRoadInfo _road # 7;
        private _roadDir = _start getDir _end;
        private _roadLen = _start distance2d _end;
        if (_roadLen < 6) then { continue };
        if (_road nearEntities (_roadLen * 0.75) isNotEqualTo []) then { continue };

        // A house close to the road for the officer to wait in
        private _houses = nearestObjects [getPosATL _road, ["House"], 50, true] select { [_x] call _fnc_isHouse };
        if (_houses isEqualTo []) then { continue };

        private _placePos = false;
        private _placeDir = _roadDir;
        for "_i" from 4 to _roadLen step 5 do {
            private _testPos = _start getPos [_i, _roadDir];
            _placePos = [_testPos, _roadDir] call A3A_fnc_checkRoadPlace;
            _placeDir = _roadDir;
            if (_placePos isEqualType []) exitWith {};
            _placePos = [_testPos, _roadDir + 180] call A3A_fnc_checkRoadPlace;
            _placeDir = _roadDir + 180;
            if (_placePos isEqualType []) exitWith {};
        };
        if (_placePos isEqualType []) exitWith { _place = [_city, selectRandom _houses, _placePos, _placeDir, selectRandom _outposts] };
    };
};

if (_place isEqualTo []) exitWith {false};
[1, _place];
