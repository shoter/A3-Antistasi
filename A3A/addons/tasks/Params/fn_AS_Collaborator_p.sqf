/*
Maintainer: Shoter
    Parameter getter for the collaborator car ambush task.
    Picks an enemy town within mission distance whose faction has police cars, an outpost of the same side
    1.5-6 km away as the destination, and a roadside spot near the town centre where the police car waits.

Arguments: none

Return Value:
    <BOOL> false if no valid parameters could be generated, otherwise
    <ARRAY> [weight, [town marker, car position ATL, car direction, destination outpost marker]]

Scope: Server
Environment: Any
Public: No
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

private _hqPos = markerPos "Synd_HQ";
private _players = allPlayers - entities "HeadlessClient_F";

private _cities = (citiesX inAreaArray [_hqPos, distanceMission, distanceMission]) - destroyedSites;
_cities = _cities select { sidesX getVariable _x in [Occupants, Invaders] } select { spawner getVariable _x != 0 };

private _place = [];
while { _place isEqualTo [] and _cities isNotEqualTo [] } do {
    private _city = _cities deleteAt floor random count _cities;
    private _side = sidesX getVariable _city;
    private _faction = Faction(_side);
    if ((_faction get "vehiclesPolice") isEqualTo []) then { continue };

    private _cityPos = markerPos _city;
    private _outposts = outposts select { sidesX getVariable _x == _side }
        select { private _dist = markerPos _x distance2d _cityPos; _dist > 1500 and _dist < 6000 };
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
        if (_placePos isEqualType []) exitWith { _place = [_city, _placePos, _placeDir, selectRandom _outposts] };
    };
};

if (_place isEqualTo []) exitWith {false};
[1, _place];
