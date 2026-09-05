/*
Maintainer: Shoter
    Finds a clear parking slot beside a road at HQ for a vehicle, facing into the road.
    Extracted from fn_spawnHCVeh so AI logistics runs (garrison resupply) park the same way as bought squads.
    The vehicle must already exist (usually created far away with simulation disabled) so its size can be measured.

Arguments:
    <OBJECT> Vehicle to find a slot for

Return Value:
    <ARRAY> [<POSITION> ATL position, <ARRAY> direction vector] or [] when no clear slot was found in 10 tries

Scope: Server
Environment: Scheduled (slow: several collision checks per try)
Public: No
Dependencies:
    respawnTeamPlayer, A3A_fnc_boxCollisionCheck

Example:
    ([_vehicle] call A3A_fnc_findHQVehicleSlot) params [["_spawnPos", []], ["_spawnDir", []]];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_vehicle", objNull, [objNull]]];
if (isNull _vehicle) exitWith { [] };

private _bb = boundingBoxReal _vehicle;
private _bbSize = _bb#1 vectorDiff _bb#0;
_bbSize params ["_vehWidth", "_vehLength", "_vehHeight"];
private _slotSize = _bbSize vectorAdd [1.5, 0.3, 0.2];
_slotSize params ["_slotWidth", "_slotLength", "_slotHeight"];
private _slotRad = sqrt (_slotWidth^2 + _slotLength^2);

private _roads = nearestTerrainObjects [markerPos respawnTeamPlayer, ["MAIN ROAD", "ROAD", "TRACK"], 100, false, true];
_roads = _roads select { count roadsConnectedTo [_x, true] <= 2 };

private _result = [];
for "_i" from 1 to 10 do {
    if (_roads isEqualTo []) exitWith {};
    private _road = selectRandom _roads;
    (getRoadInfo _road) params ["", "_roadWidth", "", "", "", "", "_begPos", "_endPos"];

    if !(_roadWidth isEqualType 0 and _begPos isEqualType []) then { continue };

    private _begPos2d = [_begPos#0, _begPos#1, 0];
    private _roadDir = _begPos2d vectorFromTo [_endPos#0, _endPos#1, 0];
    private _slotDir = [_roadDir#1, -(_roadDir#0), 0] vectorMultiply selectRandom [1, -1];
    private _sideOffset = (_slotLength + _roadWidth) / 2;

    private _slotPos = _begPos vectorAdd ((_endPos vectorDiff _begPos) vectorMultiply random 1);
    _slotPos = _slotPos vectorAdd (_slotDir vectorMultiply _sideOffset);

    // check Z diff isn't too high
    private _slotEndZ = ASLtoATL (_slotPos vectorAdd (_slotDir vectorMultiply _slotLength/2)) # 2;
    if (_slotEndZ > 1.5 or _slotEndZ < -1.2) then { continue };

    // Check for (small) objects within slot area
    private _nearObj = ASLtoATL _slotPos nearEntities _slotRad;
    _nearObj append nearestObjects [_slotPos, ["Building"], _slotRad, true];          // Pretty much all editor-placeable objects are Building
    _nearObj append nearestTerrainObjects [_slotPos, ["FENCE","WALL","TREE","HOUSE","HIDE","POWER LINES"], _slotRad, false, true];
    if (_nearObj inAreaArray [_slotPos, _slotWidth/2, _slotLength/2, _slotDir#0 atan2 _slotDir#1, true] isNotEqualTo []) then { continue };

    // Actual vehicle collision
    if ([_slotPos, _slotDir, _vehLength, _vehWidth, _vehHeight] call A3A_fnc_boxCollisionCheck) then { continue };

    // Check that path is clear-ish for exit too
    private _checkPos = _slotPos vectorAdd (_slotDir vectorMultiply -0.35*_roadwidth);
    private _checkLength = _slotLength + _roadWidth*0.7;
    if ([_checkPos, _slotDir vectorMultiply -1, _checkLength, _slotWidth, _slotHeight] call A3A_fnc_boxCollisionCheck) then { continue };

    _result = [ASLtoATL _slotPos, _slotDir vectorMultiply -1];
    break;
};

_result
