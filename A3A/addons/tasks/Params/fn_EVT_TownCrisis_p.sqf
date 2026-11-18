/*
Maintainer: Shoter
    Parameter getter for the town crisis event.
    Picks a random rebel town, whatever its support or population, that lacks at least one of the town upgrades
    (militia post, clinic, city office), and one of the missing upgrades at random. The missing upgrade decides
    the crisis: no militia post brings a riot, no clinic a plague, no city office poverty.
    Towns that have every upgrade never get a crisis, so when all rebel towns are fully built the event cannot start.
    Only one town crisis runs at a time, and none before war level 4.

Arguments: none

Return Value:
    <BOOL> false if no valid parameters could be generated, otherwise
    <ARRAY> [weight, [city marker, upgrade id]]

Scope: Server
Environment: Any
Public: No
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

#define MIN_WAR_LEVEL 4

if (tierWar < MIN_WAR_LEVEL) exitWith {false};
if ("TOWNCRISIS" in A3A_activeTasks) exitWith {false};
if (isNil "A3A_townUpgradeHM") exitWith {false};

// Upgrades the players can actually build in this modset
private _ids = ["militia", "clinic", "office"] select { (A3A_townUpgradeHM getOrDefault [_x, [""]]) # 0 != "" };
if (_ids isEqualTo []) exitWith {false};

private _candidates = [];
{
    private _city = _x;
    private _missing = _ids select { !([_city, _x] call A3A_fnc_townUpgradeHas) };
    if (_missing isNotEqualTo []) then { _candidates pushBack [_city, _missing] };
} forEach (citiesX select { sidesX getVariable [_x, sideUnknown] == teamPlayer and { !(_x in destroyedSites) } });

if (_candidates isEqualTo []) exitWith {false};

(selectRandom _candidates) params ["_city", "_missing"];
[1, [_city, selectRandom _missing]];
