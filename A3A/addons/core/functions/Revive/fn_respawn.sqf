params ["_unit"];

if (!local _unit) exitWith {};
if (_unit getVariable "respawning") exitWith {};
if (_unit != _unit getVariable ["owner",_unit]) exitWith {};
if (!isPlayer _unit) exitWith {};

_unit setVariable ["respawning",true];
removeAllUserActionEventHandlers ["A3A_core_respawn", "Activate"];
removeAllUserActionEventHandlers ["A3A_core_selfRevive", "Activate"];
// Respawn countdown from the A3A_respawnTime param: the engine waits this long in multiplayer, the spawn below in singleplayer
private _respawnTime = missionNamespace getVariable ["A3A_respawnTime", 15];
private _layer = ["A3A_infoCenter"] call BIS_fnc_rscLayer;
["Respawning",0,0,_respawnTime,0,0,_layer] spawn bis_fnc_dynamicText;

if (captive _unit) then {_unit setCaptive false};
if (isMultiplayer) exitWith {_unit setVariable ["respawning",false]; _unit setDamage 1;};

// Player statistics: in singleplayer the player never dies, so the death is counted here
[[_unit] call A3A_fnc_playerStats_getUID, [["deaths", 1]]] remoteExecCall ["A3A_fnc_playerStats_add", 2];

[_unit, _respawnTime] spawn {
    params ["_oldUnit", "_respawnTime"];
    sleep _respawnTime;
    _group = group _oldUnit;
    _newPlayer = [_group, "a3a_unit_player", getMarkerPos "respawn_guerrila", [],0, "NONE"] call A3A_fnc_createUnit;
    selectPlayer _newPlayer;
    [_oldUnit] joinSilent grpNull;
    [_newPlayer] call A3A_fnc_initRevive;
    private _module = allCurators#0;
    unassignCurator _module;
    _newPlayer assignCurator _module;
    call A3A_fnc_newPlayerSetup;
    [_newPlayer, _oldUnit] call A3A_fnc_onPlayerRespawn;
    _oldUnit setDamage 1;
    _oldUnit setVariable ["respawning",false];
};
