/*
Maintainer: Shoter
    Parameter getter for the abandoned collaborator hideout task.
    Picks a random house within mission distance of HQ, away from military sites and players,
    with room inside for the intel and the loot crate. The map only gets a search circle:
    its centre is 50-150m from the house and its radius reaches the house plus another 50-100m.
    The intel belongs to the side holding the nearest military site.

Arguments: none

Return Value:
    <BOOL> false if no valid parameters could be generated, otherwise
    <ARRAY> [weight, [house position ATL, house object, enemy side, circle centre, circle radius]]

Scope: Server
Environment: Any
Public: No
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

private _hqPos = markerPos "Synd_HQ";
private _players = allPlayers - entities "HeadlessClient_F";
private _militaryMarkers = airportsX + outposts + seaports + resourcesX + factories + controlsX;
// Lived-in houses only: no military buildings, sheds, churches or ruins
private _badTypes = ["cargo", "mil_", "military", "barrack", "bunker", "tower", "hangar", "church", "chapel", "cathedral", "mosque", "shed", "garage", "fuel", "factory", "industrial", "tank", "pier", "hospital", "ruin", "castle", "wip"];

private _fnc_isHouse = {
    params ["_house"];
    if (!alive _house or isObjectHidden _house) exitWith {false};
    private _type = toLower typeOf _house;
    if (_badTypes findIf { _x in _type } != -1) exitWith {false};
    private _positions = (_house buildingPos -1) select { !surfaceIsWater _x };
    // Room for the crate on the ground floor and the papers somewhere else
    if (count _positions < 3 or count _positions > 24) exitWith {false};
    if (_positions findIf { _x # 2 < 1 } == -1) exitWith {false};
    private _pos = getPosATL _house;
    if (_pos distance2d _hqPos < 500 or _pos distance2d _hqPos > distanceMission) exitWith {false};
    if (_militaryMarkers inAreaArray [_pos, 400, 400] isNotEqualTo []) exitWith {false};
    if (_militaryMarkers findIf { _pos inArea _x } != -1) exitWith {false};
    _players inAreaArray [_pos, 300, 300] isEqualTo [];
};

private _house = objNull;
for "_i" from 1 to 30 do {
    // Uniform over the whole mission area
    private _pos = _hqPos getPos [distanceMission * sqrt random 1, random 360];
    if (surfaceIsWater _pos) then { continue };
    private _candidates = nearestObjects [_pos, ["House"], 300, true] select { [_x] call _fnc_isHouse };
    if (_candidates isNotEqualTo []) exitWith { _house = selectRandom _candidates };
};
if (isNull _house) exitWith {
    Debug("No house found for the collaborator hideout");
    false;
};

private _housePos = getPosATL _house;
_housePos set [2, 0];

// Search circle: off-centre, and wider than it needs to be
private _center = _housePos getPos [50 + random 100, random 360];
_center set [2, 0];
private _radius = (_center distance2d _housePos) + 50 + random 50;

private _enemyMarkers = (airportsX + outposts + seaports + resourcesX + factories) select { sidesX getVariable [_x, sideUnknown] in [Occupants, Invaders] };
private _side = Occupants;
if (_enemyMarkers isNotEqualTo []) then {
    _side = sidesX getVariable ([_enemyMarkers, _housePos] call BIS_fnc_nearestPosition);
};

[1, [_housePos, _house, _side, _center, _radius]];
