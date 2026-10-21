/*
Maintainer: Shoter
    Whether a unit may scrap or retrieve a wreck. Shared by the client action menu entries, where it runs every frame
    while the player stands next to the wreck, by the work loops of players and AI, and by the server before it pays out.
    Keep it cheap and free of sleeps. Any unit may do it, engineers are only faster (see A3A_fnc_scrapDuration).
    Wrecks inside a spawned base held by the enemy are off limits until the base is captured or no fighting enemy is
    left inside it.

Arguments:
    <OBJECT> Wreck (dead vehicle)
    <OBJECT> Unit that wants to work on it

Return Value:
    <ARRAY> [<BOOL> allowed, <STRING> stringtable key of the refusal reason, "" when allowed]

Scope: Anywhere
Environment: Any
Public: No
Dependencies: A3A_fnc_canFight

Example:
    ([cursorObject, player] call A3A_fnc_scrapCanStrip) params ["_allowed", "_reason"];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_wreck", objNull, [objNull]], ["_unit", objNull, [objNull]]];

if (isNull _wreck or {alive _wreck}) exitWith { [false, "STR_A3A_fn_junkyard_scrap_notWreck"] };
// Same whitelist as the action monitor: land, air and sea vehicles, no statics (the junkyard does not sell those either)
if !((_wreck isKindOf "LandVehicle" or _wreck isKindOf "Air" or _wreck isKindOf "Ship") and !(_wreck isKindOf "StaticWeapon") and !(_wreck isKindOf "ParachuteBase")) exitWith {
    [false, "STR_A3A_fn_junkyard_scrap_notWreck"]
};
if (_wreck getVariable ["A3A_scrapStripped", false]) exitWith { [false, "STR_A3A_fn_junkyard_scrap_alreadyStripped"] };

// Wrecks inside a spawned enemy base wait until it is captured or its defenders are gone. 2 = despawned.
private _bases = (airportsX + outposts + seaports + factories + resourcesX) select { _wreck inArea _x };
private _blocked = _bases findIf {
    private _marker = _x;
    sidesX getVariable [_marker, sideUnknown] != teamPlayer
    and { spawner getVariable [_marker, 2] != 2 }
    and { ((units Occupants + units Invaders) inAreaArray _marker) findIf { _x call A3A_fnc_canFight } != -1 }
};
if (_blocked != -1) exitWith { [false, "STR_A3A_fn_junkyard_scrap_enemyBase"] };

[true, ""];
