/*
 *	Attaches teleport system to existing mast (flag). Teleport can also teleport player's group.
 *	
 *	@author 
 *		Czarny
 *	@call
 *		[teleport, sideLeader] execVM "addTeleportToPole.sqf"
  *	@args
 *		teleport: [Object] 				- existing flag which is teleport start
 *		sideLeader: [Object]			- player who can manipulate the system
 *	@return
 *		none
 *	@dependencies
 *		none
**/


// SCRIPT DEFINITIONS

teleport = _this select 0;
sideLeader = _this select 1;

interactionDistance = 5;			//meters

//diag_log format ["%1: rom | %2| %3", servertime, name player, "addTeleportToPole ENTER"];

//check if teleportTarget is already define (for JIP or respawn)
teleportTarget = missionNamespace getVariable ["teleportTarget", nil];
if(isNil "teleportTarget") then 
{
	teleportTarget = [objNull]; 
};

fnc_teleport= 
{
	private _destination = getPosATL (teleportTarget select 0);
	{
		if((_x == player) || !(isPlayer _x)) then		//is current player but not other player (can be AI)
		{
			_x setpos [(_destination select 0) + random [-20, 0, 20], (_destination select 1) + random [-20, 0, 20], 0.2]; 
		};
	} forEach units group player;
};

fnc_addTeleport= 
{	
	private _placeDistance = 4;
	private _playerDir = round (getDir player);
	private _playerPos = getPosATL player;
	
	teleportTarget set [0, "Flag_Green_F" createVehicle [(_playerPos select 0) + _placeDistance * (sin _playerDir), (_playerPos select 1) + _placeDistance * (cos _playerDir), 0]];
	
	if(isMultiplayer) then
	{
		publicVariable "teleportTarget";

		{if((side player) == (side sideLeader)) then {player setVariable ["idActionTeleport", player addAction actionTeleport];};} remoteExec ["bis_fnc_call", -2];
	}
	else
	{
		if((side player) == (side sideLeader)) then
		{
			player setVariable ["idActionTeleport", player addAction actionTeleport];
		};
	};

	if(player == sideLeader) then 
	{	
		player removeAction (player getVariable "idActionAddTeleport");
		player setVariable ["idActionRemoveTeleport", player addAction actionRemoveTeleport];
	};
};

fnc_removeTeleport= 
{
	deleteVehicle (teleportTarget select 0);

	if(player == sideLeader) then
	{
		player setVariable ["idActionAddTeleport", player addAction actionAddTeleport];
		player removeAction (player getVariable "idActionRemoveTeleport");
	};
	
	if(isMultiplayer) then
	{
		publicVariable "teleportTarget";

		if((side player) == (side sideLeader)) then
		{
			{if((side player) == (side sideLeader)) then {player removeAction (player getVariable "idActionTeleport");};} remoteExec ["bis_fnc_call", -2];
		};
	}
	else
	{
		if((side player) == (side sideLeader)) then
		{
			player removeAction (player getVariable "idActionTeleport");
		};
	};
};

actionAddTeleport = ["add teleport", fnc_addTeleport, [], 0, false, true];
actionRemoveTeleport = ["remove teleport", fnc_removeTeleport, [], 0, false, true, "", "(player distance (teleportTarget select 0) < interactionDistance) || (player distance teleport < interactionDistance)"];
actionTeleport = ["teleport", fnc_teleport, [], 0, false, true, "", "player distance teleport < interactionDistance"];

// SCRIPT EXECUTION

//removal of all actions (for respawn, revive and so on)
player removeAction (player getVariable "idActionTeleport");
player removeAction (player getVariable "idActionAddTeleport");
player removeAction (player getVariable "idActionRemoveTeleport");

if(isNull (teleportTarget select 0)) then 
{
	if(player == sideLeader) then 
	{
		player setVariable ["idActionAddTeleport", player addAction actionAddTeleport];
	};
}
else
{
	if(player == sideLeader) then 
	{
		player setVariable ["idActionRemoveTeleport", player addAction actionRemoveTeleport];
	};

	if((side player) == (side sideLeader)) then
	{
		player setVariable ["idActionTeleport", player addAction actionTeleport];
	};
};