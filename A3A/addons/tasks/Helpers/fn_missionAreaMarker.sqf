/*
Maintainer: Shoter
    Draws the mission area (A3A_missionArea) on everyone's map: a circle outline and a label at its centre.
    Removes both when no area is set; missions then centre on the HQ, as before the Mission Area button existed.

Arguments:
    None

Return Value:
    None

Scope: Server
Environment: Any
Public: No

Example:
    call A3A_tasks_fnc_missionAreaMarker;
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

#define AREA_MARKER "A3A_missionArea"
#define LABEL_MARKER "A3A_missionAreaLabel"

if (!isServer) exitWith { Error("Server-only function miscalled") };

deleteMarker AREA_MARKER;
deleteMarker LABEL_MARKER;
if (A3A_missionArea isEqualTo []) exitWith {};

A3A_missionArea params ["_pos", "_radius"];

// Built locally, then broadcast once by the last global command
createMarkerLocal [AREA_MARKER, _pos];
AREA_MARKER setMarkerShapeLocal "ELLIPSE";
AREA_MARKER setMarkerSizeLocal [_radius, _radius];
AREA_MARKER setMarkerBrushLocal "Border";
AREA_MARKER setMarkerColorLocal colorTeamPlayer;
AREA_MARKER setMarkerAlpha 1;

createMarkerLocal [LABEL_MARKER, _pos];
LABEL_MARKER setMarkerShapeLocal "ICON";
LABEL_MARKER setMarkerTypeLocal "mil_dot";
LABEL_MARKER setMarkerColorLocal colorTeamPlayer;
LABEL_MARKER setMarkerText format [localize "STR_A3A_Tasks_missionArea_marker", _radius / 1000];
