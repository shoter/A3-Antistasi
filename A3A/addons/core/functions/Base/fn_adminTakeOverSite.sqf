/*
Maintainer: Shoter
    Admin action: hands an enemy site to the rebels at once, emptied.
    Works for airfields, outposts, seaports, factories, resources and towns.

    What happens:
    - A spawned site is despawned first, which deletes its troops, vehicles, statics, buildings, flag and loot crate.
    - The garrison data is wiped: no troops, no vehicles, no statics, no buildings, no support vehicles.
    - The site turns rebel and its map marker is redrawn. Towns get at least 80 support, as after a won town battle,
      so they do not flip back on the next small support loss.
    - War tier is recalculated silently.

    What does not happen, unlike a normal capture (A3A_fnc_markerChange, A3A_fnc_citySideChange):
    no notifications, no chronicle entry, no aggression change, no counterattack, no player rewards,
    no HR lump for a town.

    Income and HR of every side follow from site ownership on their next ticks
    (A3A_fnc_resourcecheck for the rebels, A3A_fnc_aggressionUpdateLoop for the enemies), so nothing is paid here.

Arguments:
    <STRING> Marker of the site

Return Value:
    Nothing

Scope: Server, Global Effect
Environment: Unscheduled
Public: No
Dependencies:
    A3A_fnc_garrisonServer_despawn, A3A_fnc_garrisonServer_changeSide, A3A_fnc_mrkUpdate, A3A_fnc_tierCheck

Example:
    [_marker] remoteExecCall ["A3A_fnc_adminTakeOverSite", 2];

License: APL-ND
*/

#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if (!isServer) exitWith { Error("Miscalled server-only function") };

params [["_marker", "", [""]]];

// Only logged-in or voted admins, plus the player of a hosted or singleplayer game (see A3A_fnc_factionDebugData)
private _client = [clientOwner, remoteExecutedOwner] select (isRemoteExecuted && {remoteExecutedOwner > 0});
private _isAdmin = (hasInterface && {_client == clientOwner}) || {admin _client != 0};
if (!_isAdmin) exitWith { Error_2("Site take over of %1 requested by non-admin machine %2", _marker, _client) };

private _fnc_refuse = {
    params ["_reason"];
    Error_2("Admin take over of %1 refused: %2", _marker, _reason);
    [localize "STR_antistasi_dialogs_main_admin_take_over_title", format [localize "STR_antistasi_dialogs_main_admin_take_over_refused", _reason]]
        remoteExecCall ["A3A_fnc_customHint", _client];
};

if !(_marker in (airportsX + outposts + seaports + factories + resourcesX + citiesX)) exitWith { ["not a major site or town"] call _fnc_refuse };
private _loser = sidesX getVariable [_marker, sideUnknown];
if (_loser == teamPlayer) exitWith { ["already rebel"] call _fnc_refuse };
if (isNil {A3A_garrison get _marker}) exitWith { ["no garrison data"] call _fnc_refuse };

Info_2("Admin take over: %1 from %2", _marker, _loser);

// 1. Remove everything spawned at the site. Despawn deletes troops, vehicles, buildings, flag and crate.
//    If players are near, the spawn loop spawns the site again as an empty rebel site.
if (spawner getVariable [_marker, 2] != 2) then {
    [_marker] call A3A_fnc_garrisonServer_despawn;
};

// 2. Flip the side. changeSide clears the troops (rebel format) and the paid garrison, and ends running supports
sidesX setVariable [_marker, teamPlayer, true];
[_marker, teamPlayer, _loser] call A3A_fnc_garrisonServer_changeSide;

// 3. No vehicles, statics or buildings come with the site
private _garrison = A3A_garrison get _marker;
_garrison set ["troops", []];
_garrison set ["vehicles", []];
_garrison set ["buildings", []];
_garrison set ["supportVehicles", createHashMap];

// 4. Towns: keep the support high enough not to flip back (citySupportChange flips a rebel town below 40)
if (_marker in citiesX) then {
    private _cityData = A3A_cityData getVariable _marker;
    _cityData set [1, (_cityData # 1) max 80];
    A3A_cityData setVariable [_marker, _cityData, true];
};

// 5. Kill zones, as in markerChange: drop the site from the nearest rebel airfield's list, clear its own list
if !(_marker in airportsX) then {
    private _rebelAirports = airportsX select { sidesX getVariable [_x, sideUnknown] == teamPlayer };
    if (_rebelAirports isEqualTo []) exitWith {};
    private _nearAirport = [_rebelAirports, _marker] call BIS_fnc_nearestPosition;
    killZones setVariable [_nearAirport, (killZones getVariable [_nearAirport, []]) - [_marker], true];
};
if (_marker in airportsX or {_marker in outposts}) then { killZones setVariable [_marker, [], true] };

// 6. Map marker, war tier (silent) and listeners of the usual side change event
[_marker] call A3A_fnc_mrkUpdate;
[true] call A3A_fnc_tierCheck;
["markerChange", [_marker, teamPlayer]] call EFUNC(Events,triggerEvent);

Info_1("Admin take over of %1 finished", _marker);
