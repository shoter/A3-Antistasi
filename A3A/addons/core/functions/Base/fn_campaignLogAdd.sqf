/*
Maintainer: Shoter
    Appends an entry to the campaign chronicle kept on the server and bumps the version clients use to fetch deltas.
    Entries stay JSON-safe (numbers, strings, arrays) so they survive the save file; the text is localized on the client
    by A3A_GUI_fnc_chronicleTab from the type id, the target, the actor and the extra params.

Arguments:
    <STRING> Event type id, localized on the client as STR_antistasi_dialogs_main_chronicle_ev_<type>
    <STRING or POSITION> Marker name or position the entry points to on the map, "" when there is none (default "")
    <ARRAY> Extra format params for the client-side text: strings, numbers, or sides (converted to faction names) (default [])
    <STRING or POSITION> Actor name(s), or a position resolved to the rebel players within 500 m of it (default "")

Return Value:
    <nil>

Scope: Server
Environment: Any
Public: No
Dependencies: A3A_fnc_junkyardClock, A3A_campaignLogCap

Example:
    ["siteCaptured", "outpost_3", [Occupants], markerPos "outpost_3"] call A3A_fnc_campaignLogAdd;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

#define ACTOR_RADIUS 500
#define ACTOR_MAX_NAMES 4

if !(isServer) exitWith { Error("Attempted to call server function as non-server") };

params [["_type", "", [""]], ["_target", "", ["", []]], ["_params", [], [[]]], ["_actor", "", ["", []]]];

if (_type isEqualTo "") exitWith { Error("Chronicle entry without a type") };

// Sides are not JSON-safe, store the faction name instead. Unknown sides become an empty string.
private _fnc_sideName = {
    params ["_side"];
    if !(_side in [teamPlayer, Occupants, Invaders]) exitWith { "" };
    Faction(_side) getOrDefault ["name", ""]
};
_params = _params apply { if (_x isEqualType sideUnknown) then { [_x] call _fnc_sideName } else { _x } };

// A position resolves to the rebel players near it, e.g. the ones who captured a site
if (_actor isEqualType []) then {
    private _names = (allPlayers inAreaArray [_actor, ACTOR_RADIUS, ACTOR_RADIUS]) select { side group _x == teamPlayer } apply { name _x };
    private _extra = (count _names) - ACTOR_MAX_NAMES;
    _names resize ((count _names) min ACTOR_MAX_NAMES);
    _actor = _names joinString ", ";
    if (_extra > 0) then { _actor = format ["%1 +%2", _actor, _extra] };
};

A3A_campaignLogVersion = A3A_campaignLogVersion + 1;
publicVariable "A3A_campaignLogVersion";

A3A_campaignLog pushBack [A3A_campaignLogVersion, call A3A_fnc_junkyardClock, _type, _target, _params, _actor];
if (count A3A_campaignLog > A3A_campaignLogCap) then {
    A3A_campaignLog deleteRange [0, count A3A_campaignLog - A3A_campaignLogCap];
};

Debug_3("Chronicle #%1: %2 at %3", A3A_campaignLogVersion, _type, _target);
