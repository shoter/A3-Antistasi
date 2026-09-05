// Side change function for cities
// forceSupport is optional numerical cap value for support

#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

Trace_1("Called with %1", _this);

params ["_city", "_side", ["_forceSupport", -1]];

private _cityData = A3A_cityData getVariable _city;
private _prevSide = sidesX getVariable _city;

if (_side == teamPlayer) then {
	["TaskSucceeded", ["", format [localize "STR_A3A_fn_init_resourceCheck_cityChange",_city,FactionGet(reb,"name")]]] remoteExec ["BIS_fnc_showNotification",teamPlayer];
	if (_forceSupport >= 0) then { _cityData set [1, _forceSupport max _cityData#1] };
	[A3A_rebelHRLumpMult * (_cityData#2 max 0), 0] spawn A3A_fnc_resourcesFIA;

	private _aggroMod = sqrt (A3A_cityPop get _city) / 2;
	[Occupants, _aggroMod, 60] spawn A3A_fnc_addAggression;
	[Invaders, _aggroMod, 60] spawn A3A_fnc_addAggression;
	//[_city] call A3A_fnc_deleteNearSites;
} else {
	if (_forceSupport >= 0) then { _cityData set [1, _forceSupport min _cityData#1] };
	if (_city in destroyedSites) exitWith {};			// don't double-flag on punishment
	private _taskType = ["TaskUpdated", "TaskFailed"] select (_prevSide == teamPlayer);
	[_taskType, ["", format [localize "STR_A3A_fn_init_resourceCheck_cityChange",_city,Faction(_side) get "name"]]] remoteExec ["BIS_fnc_showNotification",teamPlayer];
};

sidesX setVariable [_city, _side, true];

// Chronicle entry. Destroyed towns are logged by whatever destroyed them, support drift may call this with the same side
if (_prevSide != _side && {!(_city in destroyedSites)}) then {
	call {
		if (_side == teamPlayer) exitWith { ["townCaptured", _city, [_prevSide], getMarkerPos _city] call A3A_fnc_campaignLogAdd };
		if (_prevSide == teamPlayer) exitWith { ["townLost", _city, [_side]] call A3A_fnc_campaignLogAdd };
		["townChanged", _city, [_side, _prevSide]] call A3A_fnc_campaignLogAdd;
	};
};

[_city, _side, _prevSide] call A3A_fnc_garrisonServer_changeSide;

// Rebel town upgrades do not survive losing the town
if (_prevSide == teamPlayer and _side != teamPlayer) then { [_city, "flipped"] call A3A_fnc_townUpgradeClearCity };

_cityData set [2, _cityData#2 min 0];					// clear accumulated HR if positive
A3A_cityData setVariable [_city, _cityData, true];		// publish. Some client-side stuff needs support data
[_city] call A3A_fnc_mrkUpdate;
