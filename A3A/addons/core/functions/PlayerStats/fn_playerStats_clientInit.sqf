/*
Maintainer: Shoter
    Client side of the player statistics: counts the shots the local player fires per weapon or vehicle, and the
    ones that hit an enemy, and sends the totals to the server once a minute. The Fired handler is attached to the current body and re-attached after
    every respawn. Called once from initClient.

Arguments:
    None

Return Value:
    Nothing

Scope: Clients
Environment: Any
Public: No

Example:
    call A3A_fnc_playerStats_clientInit;

License: APL-ND

*/

#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

// Seconds between sending the shot counts to the server
#define FLUSH_INTERVAL 60

if (!hasInterface) exitWith {};
if (!isNil "A3A_playerStats_clientInitDone") exitWith {};
A3A_playerStats_clientInitDone = true;

A3A_playerStats_shotsBuffer = createHashMap;        // weapon or vehicle class -> [shots, hits] since the last flush

[player] call A3A_fnc_playerStats_attachFiredEH;

// Multiplayer respawns give the player a fresh body without any event handlers
addMissionEventHandler ["EntityRespawned", {
    params ["_newEntity"];
    if (_newEntity == player) then { [_newEntity] call A3A_fnc_playerStats_attachFiredEH };
}];

[] spawn {
    while { true } do {
        sleep FLUSH_INTERVAL;
        if (A3A_playerStats_shotsBuffer isEqualTo createHashMap) then { continue };
        private _deltas = [];
        { _deltas pushBack [_x, [0, 0, 0, 0, _y select 0, _y select 1]] } forEach A3A_playerStats_shotsBuffer;
        A3A_playerStats_shotsBuffer = createHashMap;
        [[player] call A3A_fnc_playerStats_getUID, [], [], _deltas] remoteExecCall ["A3A_fnc_playerStats_add", 2];
    };
};
