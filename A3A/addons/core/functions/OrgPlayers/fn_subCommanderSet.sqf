/*
Maintainer: Shoter
    Designates a player as sub-commander or takes the role away again. Only the current commander may do this.
    Sub-commanders recruit their own high command squads and pay for junkyard vehicles and utility items
    (builder boxes included) from the faction funds. The list is kept by UID, broadcast to all clients and saved,
    so it outlives reconnects, restarts and commander changes.
    A player who loses the role hands their squads over to the commander. Everyone is told about the change
    and the chronicle records it.

Arguments:
    <OBJECT> Player requesting the change, has to be the commander
    <STRING> UID of the player to designate or remove
    <BOOL> True to designate, false to remove (default true)

Return Value:
    <BOOL> True if the list changed

Scope: Server
Environment: Unscheduled
Public: No
Dependencies:
    A3A_subCommanders, A3A_fnc_subCommanderTransferSquads, A3A_fnc_subCommanderNotify, A3A_fnc_campaignLogAdd,
    A3A_GUI_fnc_subCommandersDialog

Example:
    [player, _uid, true] remoteExecCall ["A3A_fnc_subCommanderSet", 2];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if !(isServer) exitWith { Error("Attempted to call server function as non-server"); false };
params [["_commander", objNull, [objNull]], ["_uid", "", [""]], ["_assign", true, [true]]];

if (isNull _commander || {_uid == ""}) exitWith { false };
if (_commander != theBoss) exitWith {
    Info_1("%1 tried to change the sub-commanders without being commander", name _commander);
    false
};

// Body of the target when they are online, the body behind a remote-controlled AI included
private _unit = objNull;
{
    if (([_x] call A3A_fnc_playerStats_getUID) == _uid) exitWith { _unit = _x getVariable ["owner", _x] };
} forEach (allPlayers - entities "HeadlessClient_F");

// A dead body waiting for respawn may have lost its name, the player statistics remember it
private _fnc_name = {
    private _name = name _unit;
    if (_name == "" || {_name find "Error" == 0}) then {
        private _stats = A3A_playerStats getOrDefault [_uid, createHashMap];
        _name = if (_stats isEqualType createHashMap) then { _stats getOrDefault ["name", _uid] } else { _uid };
    };
    _name
};

private _changed = if (_assign) then {
    // Only rebel players on the server can be designated, and the commander needs no second role
    if (isNull _unit || {_unit == theBoss} || {_uid in A3A_subCommanders}) exitWith { false };
    if (side group _unit in [Occupants, Invaders]) exitWith { false };

    private _name = call _fnc_name;
    A3A_subCommanders set [_uid, _name];
    publicVariable "A3A_subCommanders";

    Info_2("Commander %1 designated %2 as sub-commander", name _commander, _name);
    ["subCommanderAssigned", "", [_name], name _commander] call A3A_fnc_campaignLogAdd;
    ["assigned", [_uid, _name, name _commander]] remoteExecCall ["A3A_fnc_subCommanderNotify", 0];
    true
} else {
    if !(_uid in A3A_subCommanders) exitWith { false };

    private _name = A3A_subCommanders deleteAt _uid;
    if (!isNull _unit) then { _name = call _fnc_name };
    publicVariable "A3A_subCommanders";

    // Squads stay in the field under the commander
    [_unit] call A3A_fnc_subCommanderTransferSquads;

    Info_2("Commander %1 removed %2 from the sub-commanders", name _commander, _name);
    ["subCommanderRemoved", "", [_name], name _commander] call A3A_fnc_campaignLogAdd;
    ["removed", [_uid, _name, name _commander]] remoteExecCall ["A3A_fnc_subCommanderNotify", 0];
    true
};

// Nothing changed, e.g. the player just left: the commander's dialog still has to come back to life
if (!_changed) then { ["update"] remoteExecCall ["A3A_GUI_fnc_subCommandersDialog", _commander] };
_changed
