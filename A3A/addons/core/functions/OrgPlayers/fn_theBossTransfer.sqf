if !(isServer) exitWith {};
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()
params [["_newBoss", objNull], ["_silent", false]];

private _oldBoss = theBoss;
theBoss = _newBoss;
publicVariable "theBoss";

// Chronicle entry, silent transfers are respawns and admin fixes
if (!_silent && {!isNull _newBoss} && {_oldBoss != _newBoss}) then {
    if (isNull _oldBoss) then {
        ["commanderAssigned", "", [], name _newBoss] call A3A_fnc_campaignLogAdd;
    } else {
        ["commanderChanged", "", [name _oldBoss], name _newBoss] call A3A_fnc_campaignLogAdd;
    };
};

if (!isNull _oldBoss) then {
    Debug_1("Removing %1 from Boss roles.", name _oldBoss);

	bossHCGroupsTransfer = hcAllGroups _oldBoss;
	hcRemoveAllGroups _oldBoss;

	_oldBoss synchronizeObjectsRemove [HC_commanderX];
	HC_commanderX synchronizeObjectsRemove [_oldBoss];
	[nil,true] remoteExecCall ["A3A_fnc_unitTraits", _oldBoss];
};

if (isNull _newBoss) exitWith {
	[_silent] spawn {
		params ["_silent"];
		sleep 5;
		private _textX = format [localize "STR_A3A_fn_orgp_tBTransfer_noEligible"];
		if (!_silent) then {[petros,"hint",_textX, localize "STR_A3A_fn_orgp_tBTransfer_newCommTitle"] remoteExec ["A3A_fnc_commsMP", 0]};
		[] remoteExec ["A3A_fnc_statistics",[teamPlayer,civilian]];
	};
};

[group theBoss, theBoss] remoteExec ["selectLeader", groupOwner group theBoss];

// The commander needs no second role: a sub-commander who takes command leaves the sub-commanders
private _bossUID = [theBoss] call A3A_fnc_playerStats_getUID;
if (_bossUID in A3A_subCommanders) then {
	A3A_subCommanders deleteAt _bossUID;
	publicVariable "A3A_subCommanders";
};

theBoss synchronizeObjectsAdd [HC_commanderX];
HC_commanderX synchronizeObjectsAdd [theBoss];

if (!isNil "bossHCGroupsTransfer") then
{
    Debug("Found previous HC groups, transferring.");
	{
		theBoss hcSetGroup [_x];
		_x setGroupOwner owner theBoss;
	} forEach bossHCGroupsTransfer;
	bossHCGroupsTransfer = nil;
}
else {
	// Boss got lost somewhere, try to find HC groups by scanning
    Debug("No previous HC groups found, scanning all groups.");
	{
		// Squads on the high command bar of a sub-commander stay with them. The UID check covers a sub-commander who is remote controlling a unit, their body is no player then.
		private _hcLeader = hcLeader _x;
		if ((leader _x getVariable ["spawner",false]) and (!isPlayer leader _x) and (side _x == teamPlayer) and (!isPlayer _hcLeader) and !([_hcLeader] call A3A_fnc_isSubCommander)) then
		{
			theBoss hcSetGroup [_x];
			_x setGroupOwner owner theBoss;
		};
	} forEach allGroups;
};

// Squads of sub-commanders who left while there was no commander
{
	if (!isNull _x and {isNull hcLeader _x}) then
	{
		theBoss hcSetGroup [_x];
		_x setGroupOwner owner theBoss;
	};
} forEach A3A_orphanHCGroups;
A3A_orphanHCGroups = [];
["commander",true] remoteExecCall ["A3A_fnc_unitTraits", theBoss];

Debug_1("New boss %1 set.", name theBoss);

[_silent] spawn {
	params ["_silent"];
	sleep 5;
	private _textX = format [localize "STR_A3A_fn_orgp_tBTransfer_newCommLong", name theBoss];
	if (!_silent) then {[petros,"hint",_textX, localize "STR_A3A_fn_orgp_tBTransfer_newCommTitle"] remoteExec ["A3A_fnc_commsMP", 0]};
	[] remoteExec ["A3A_fnc_statistics",[teamPlayer,civilian]];
};
