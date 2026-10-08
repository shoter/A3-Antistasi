/*  
    Garrison enemy group at marker and patrol or despawn

Scope: Server or HC
Environment: Scheduled, should be spawned

Parameters:
    <GROUP> Group to order
    <STRING> Nearby friendly marker to garrison
    <BOOL> Optional: True if the troops don't count against the garrison size (default false)
    <BOOL> Optional: True to leave the group where it is instead of patrolling, e.g. a vehicle crew (default false)
*/

#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params ["_group", "_marker", ["_uncapped", false], ["_noPatrol", false]];

if (!local _group) exitWith {
    Error("Called with non-local group");
    _this remoteExec ["A3A_fnc_enemyGarrison", leader _group];
};
if (sidesX getVariable _marker != side _group) exitWith {
    Error("Target marker changed side, switching to RTB");
    [_group] spawn A3A_fnc_enemyReturnToBase;
};
if (leader _group distance2d markerPos _marker > 500) then {
    ServerInfo_1("Warning: Garrisoning group %1m from marker", leader _group distance2d markerPos _marker);
};

// Remove from other AI script
private _AIScriptHandle = _group getVariable "A3A_AIScriptHandle";
if (!isNil "_AIScriptHandle") then { terminate _AIScriptHandle; _group setVariable ["A3A_AIScriptHandle", nil]; };

// Remove from despawner. Probably shouldn't be in there?
private _despawnerHandle = _group getVariable "A3A_despawnerHandle";
if (!isNil "_despawnerHandle") then { terminate _despawnerHandle; _group setVariable ["A3A_despawnerHandle", nil]; };

ServerDebug_2("Adding group %1 to garrison at %2", _group, _marker);

// Add units to the garrison. Should handle everything else
[_marker, _group, _uncapped, _noPatrol] remoteExecCall ["A3A_fnc_garrisonServer_addGroup", 2];
