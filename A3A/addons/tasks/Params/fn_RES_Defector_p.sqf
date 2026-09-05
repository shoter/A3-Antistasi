/*
Maintainer: Shoter
    Parameter getter for the defector escort task.
    Picks an enemy outpost (or airbase) within mission distance, a roadside pickup spot
    in the countryside near it, and the delivery variant.

Arguments: none

Return Value:
    <BOOL> false if no valid parameters could be generated, otherwise
    <ARRAY> [weight, [source marker, pickup position ATL, car direction, variant ("hq" or "boat"), destination marker]]

Scope: Server
Environment: Any
Public: No
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

private _hqPos = markerPos "Synd_HQ";
private _players = allPlayers - entities "HeadlessClient_F";

private _sources = outposts inAreaArrayIndexes [_hqPos, distanceMission, distanceMission] apply { outposts#_x };
if (_sources isEqualTo []) then {
    _sources = airportsX inAreaArrayIndexes [_hqPos, distanceMission, distanceMission] apply { airportsX#_x };
};
_sources = _sources select { sidesX getVariable _x != teamPlayer };

private _place = [];
while {_place isEqualTo [] and _sources isNotEqualTo []} do {
    private _source = _sources deleteAt floor random count _sources;
    private _sourcePos = markerPos _source;
    private _otherMarkers = (markersX - [_source]) inAreaArray [_sourcePos, 1500, 1500];

    // Roads 400-1000m from the outpost: not a bridge, not a junction, away from other locations and players
    private _roads = (_sourcePos nearRoads 1000) select { _x distance2d _sourcePos > 400 }
        select { getPosATL _x # 2 < 0.5 }
        select { count roadsConnectedTo _x == 2 }
        select { _otherMarkers inAreaArray [getPosATL _x, 300, 300] isEqualTo [] }
        select { _players inAreaArray [getPosATL _x, 500, 500] isEqualTo [] };

    private _tries = 30;
    while {_place isEqualTo [] and _roads isNotEqualTo [] and _tries > 0} do {
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
        if (_placePos isEqualType []) exitWith { _place = [_source, _placePos, _placeDir] };
    };
};
if (_place isEqualTo []) exitWith {false};

// Delivery variant: boat extraction from a rebel seaport when one is available, otherwise HQ/airbase
private _variant = "hq";
private _destMrk = "Synd_HQ";
private _rebelPorts = seaports select { sidesX getVariable _x == teamPlayer }
    select { markerPos _x distance2d _hqPos < distanceMission + 1000 }
    select { markerPos _x distance2d (_place#1) > 1500 };
if (_rebelPorts isNotEqualTo [] and random 1 < 0.5) then {
    _variant = "boat";
    _destMrk = selectRandom _rebelPorts;
};

[1, _place + [_variant, _destMrk]];
