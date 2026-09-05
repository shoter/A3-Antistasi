/*  Helicopter flies a combat landing approach, lands and unloads cargo group before returning to base

Scope: Server or HC
Environment: Scheduled, spawned

Parameters:
    <OBJECT> The helicopter to control
    <GROUP> Crew group for helicopter
    <GROUP> Cargo group for helicopter
    <POSATL> Destination position for troops to attack after landing
    <POSATL> Position for heli to return to after offloading
    <POSATL> Landing position for heli
*/

params ["_helicopter", "_crewGroup", "_cargoGroup", "_posDestination", "_originPos", "_landPos"];

// avoid weird situations where they receive RTB instructions before they finish unloading
_crewGroup setVariable ["A3A_AIScriptHandle", _thisScript];
_cargoGroup setVariable ["A3A_AIScriptHandle", _thisScript];

private _midHeight = [100, 150] select (A3A_climate isEqualTo "tropical");

// Approach and bezier descent, shared with the air taxi
([_helicopter, _crewGroup, _landPos] call A3A_fnc_heliLandAtPos) params ["", "_landPad"];

_cargoGroup leaveVehicle _helicopter;
private _cargoWP1 = _cargoGroup addWaypoint [_posDestination, 10];
_cargoWP1 setWaypointType "MOVE";
_cargoWP1 setWaypointBehaviour "AWARE";
_cargoWP1 setWaypointSpeed "FULL";
private _cargoWP2 = _cargoGroup addWaypoint [_posDestination, 50];
_cargoWP2 setWaypointType "SAD";
_cargoWP2 setWaypointBehaviour "COMBAT";
_cargoGroup spawn A3A_fnc_attackDrillAI;

private _driver = driver _helicopter;
if(!canMove _helicopter || !alive _driver) exitWith { deleteVehicle _landPad };

[_helicopter] call A3A_fnc_smokeCoverAuto;          // Already done by GetOut handler in AIVehInit?

private _timeout = time + 5 + count units _cargoGroup;
while {units _cargoGroup findIf { _x in _helicopter } != -1 and time < _timeout} do {
    _helicopter setVelocity [0,0,-0.5];           // bit of help to keep the thing stable
    sleep 1;
};

// Heli RTB
deleteVehicle _landPad;
_helicopter flyInHeight _midHeight;

private _vehWP1 = _crewGroup addWaypoint [_originPos, 0];
_vehWP1 setWaypointType "MOVE";
_vehWP1 setWaypointStatements ["true", "if (local this and alive this) then { deleteVehicle (vehicle this); {deleteVehicle _x} forEach thisList }"];
_vehWP1 setWaypointBehaviour "CARELESS";
_crewGroup setCurrentWaypoint _vehWP1;

driver _helicopter action ["engineOn", _helicopter];        // needed for some helis (eg Ghost Hawk)
