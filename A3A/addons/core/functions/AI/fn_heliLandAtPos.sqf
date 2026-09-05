/*
Maintainer: Shoter
    Flies a helicopter to a position and lands it, or holds a hover above it, using the combat
    landing approach: waypoint approach, then a bezier descent driven by setVelocityTransformation.
    Extracted from A3A_fnc_combatLanding so the air taxi can share it.
    Creates an invisible helipad that the caller must delete; it is also stored as "LandingPad" on the helicopter.

Arguments:
    <OBJECT> Helicopter
    <GROUP> Crew group
    <POSATL> Landing position
    <NUMBER> Hover height above the pad, 0 lands [DEFAULT = 0]
    <NUMBER> Seconds allowed for the descent before giving up, the approach adds 25 m/s worth of flight time [DEFAULT = 120]

Return Value:
    <ARRAY> [<BOOL> landed or hovering at the position, <OBJECT> helipad]

Scope: Server or HC
Environment: Scheduled
Public: No
Dependencies:
    A3A_climate

Example:
    [_heli, _crewGroup, _landPos] call A3A_fnc_heliLandAtPos params ["_landed", "_landPad"];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params ["_helicopter", "_crewGroup", "_landPos", ["_hoverHeight", 0, [0]], ["_timeout", 120, [0]]];

private _deadline = time + _timeout + (_helicopter distance2D _landPos) / 25;      // QRF helis are sent from far away
private _fnc_canContinue = { alive _helicopter && { canMove _helicopter } && { alive driver _helicopter } && { time < _deadline } };

private _landPad = createVehicle ["Land_HelipadEmpty_F", _landPos, [], 0, "NONE"];
_helicopter setVariable ["LandingPad", _landPad, true];             // cleared up (eventually) by heli deletion handler

//Create the waypoints for the crewGroup
private _vehWP0 = _crewGroup addWaypoint [_landPos, 0];
_vehWP0 setWaypointType "MOVE";
_vehWP0 setWaypointSpeed "FULL";
_vehWP0 setWaypointCompletionRadius 150;
_vehWP0 setWaypointBehaviour "CARELESS";
_crewGroup setCurrentWaypoint _vehWP0;

private _midHeight = [100, 150] select (A3A_climate isEqualTo "tropical");
_helicopter flyInHeight _midHeight;

waitUntil {sleep 1; (_helicopter distance2D _landPos) < 1500 || { !(call _fnc_canContinue) }};
_helicopter limitSpeed 250;         // just so the Osprey slows down a bit, really
waitUntil {sleep 1; (_helicopter distance2D _landPos) < 600 || { !(call _fnc_canContinue) }};
if !(call _fnc_canContinue) exitWith { [false, _landPad] };

_helicopter flyInHeight _hoverHeight;                       // helps to keep it near the ground after landing
if (_hoverHeight == 0) then { _helicopter land "LAND" };    // also drops the gear on the huron

// Landing path setup
private _endPos = (getPosASL _landPad) vectorAdd [0, 0, _hoverHeight];
private _startPos = getPosASL _helicopter;
private _midPos = _endPos vectorAdd [0,0,_midHeight];

private _initialVelocity = (velocity _helicopter);
_initialVelocity set [2, 0];
private _velocityVector = +_initialVelocity;
_initialVelocity = (vectorMagnitude _initialVelocity) max 5;      // floor: starting from a hover the original never finished
private _initialSpeed = (speed _helicopter/3.6) max 5;
//We got the initial velocity of the heli

private _distance = _startPos distance _midPos;
private _landingTime = _distance/_initialVelocity * 1.35;

private _maxAngle = ((_initialVelocity * _initialVelocity/3600) * 35) min 35;

//Starting land approach with bezier curve
private _startToMidVector = _midPos vectorDiff _startPos;
private _midToEndVector = _endPos vectorDiff _midPos;

private _vectorDir = vectorDir _helicopter;
private _vectorUp = vectorUp _helicopter;

private _interval = 0;
private _time = 0;
private _angleStep = 0.25;
private _angleTarget = 0;
private _angleIs = 0;
private _angleDiff = 0;
private _heightDiff = 0;
private _backFactor = 0;


private _driver = driver _helicopter;
while {_interval < 0.9999} do
{
    //Update data
    _vectorDir = vectorDir _helicopter;
    _vectorUp = vectorUp _helicopter;

    //Calculating the current angle and what the helicopter should turn too
    _angleTarget = sin (_interval * 180) * _maxAngle;
    _angleIs = (asin (_vectorDir select 2));
    _angleDiff = _angleTarget - _angleIs;
    if(_angleDiff > _angleStep) then {_angleDiff = _angleStep;};
    if(_angleDiff < -_angleStep) then {_angleDiff = -_angleStep;};

    //Calculating the height and back value needed
    _backFactor = -tan (_angleDiff);
    _vectorUp = _vectorUp vectorAdd (_vectorDir vectorMultiply _backFactor);

    _heightDiff = (sin (_angleIs + _angleDiff)) - (_vectorDir select 2);
    _vectorDir = _vectorDir vectorAdd [0, 0, _heightDiff];

    private _lineStart = _startPos vectorAdd (_startToMidVector vectorMultiply _interval);
    private _lineEnd = _midPos vectorAdd (_midToEndVector vectorMultiply _interval);

    _helicopter setVelocityTransformation
    [
        _lineStart,
        _lineEnd,
        _velocityVector,
        _velocityVector,
        _vectorDir,
        _vectorDir,
        _vectorUp,
        _vectorUp,
        _interval
    ];

    _time = time;
    sleep 0.001;
    _interval = _interval + (((time - _time)/_landingTime) * (1 - (_interval / 2)));

    _velocityVector = _lineEnd vectorDiff _lineStart;
    _velocityVector = (vectorNormalized _velocityVector) vectorMultiply (_initialSpeed * (1 - _interval));

    if(!canMove _helicopter || !alive _driver || time > _deadline) exitWith {};
};

[_interval >= 0.9999 && { canMove _helicopter } && { alive _driver }, _landPad]
