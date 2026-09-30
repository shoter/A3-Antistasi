/*
Maintainer: Shoter
    Server-side function that sends the enemy faction debug numbers to the Factions tab of the requesting admin.
    Only logged-in or voted admins get an answer, plus the player of a hosted or singleplayer game.

Arguments:
    None, the answer goes to the machine that remote executed the call.

Return Value:
    Nothing

Scope: Server, Local Arguments, Global Effect
Environment: Unscheduled
Public: No
Dependencies:
    Enemy resource and aggression variables of fn_initVarServer, supports of fn_initSupports

Example:
    [] remoteExecCall ["A3A_fnc_factionDebugData", 2];

License: APL-ND

*/

#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if (!isServer) exitWith { Error("Miscalled server-only function") };

// The server's own player (hosted or singleplayer game) calls this locally
private _client = [clientOwner, remoteExecutedOwner] select (isRemoteExecuted && {remoteExecutedOwner > 0});
private _isAdmin = (hasInterface && {_client == clientOwner}) || {admin _client != 0};
if (!_isAdmin) exitWith { Error_1("Faction debug data requested by non-admin machine %1", _client) };

private _global = createHashMapFromArray [
    ["activePlayers", A3A_activePlayerCount],
    ["tierWar", tierWar],
    ["playerScale", A3A_balancePlayerScale],
    ["resourceRate", A3A_balanceResourceRate],
    ["vehicleCost", A3A_balanceVehicleCost],
    ["enemyMul", A3A_enemyBalanceMul / 10],
    ["attackMul", A3A_enemyAttackMul / 10],
    ["invaderMul", A3A_invaderBalanceMul / 10],
    ["punishmentDefBuff", A3A_punishmentDefBuff],
    ["bigAttack", bigAttackInProgress]
];

private _siteLists = [airportsX, outposts, seaports, factories, resourcesX, citiesX];
private _sides = [Occupants, Invaders] apply {
    private _side = _x;
    private _isOcc = _side == Occupants;

    // Recent damage entries are [x, y, minutes left * 1000 + value]
    private _damageEvents = [A3A_recentDamageInv, A3A_recentDamageOcc] select _isOcc;
    private _damageValue = 0;
    { _damageValue = _damageValue + (_x#2) % 1000 } forEach _damageEvents;

    // Enemy garrisons store troops as [count, quality]
    private _sites = _siteLists apply { private _list = _x; {sidesX getVariable [_x, sideUnknown] == _side} count _list };
    private _troops = 0; private _troopsMax = 0; private _vehicles = 0;
    private _police = 0; private _policeMax = 0;
    {
        if (sidesX getVariable [_x, sideUnknown] != _side) then { continue };
        private _garrison = A3A_garrison getOrDefault [_x, createHashMap];
        private _troopData = _garrison getOrDefault ["troops", []];
        private _count = if (_troopData isNotEqualTo [] && {_troopData#0 isEqualType 0}) then { _troopData#0 } else { 0 };
        private _max = A3A_garrisonSize getOrDefault [_x, 0];
        if (_x in citiesX) then {
            _police = _police + _count; _policeMax = _policeMax + _max;
        } else {
            _troops = _troops + _count; _troopsMax = _troopsMax + _max;
            _vehicles = _vehicles + count (_garrison getOrDefault ["vehicles", []]);
        };
    } forEach (markersX - ["Synd_HQ"]);

    private _supportSpend = 0;
    { if (_x#0 == _side && {_x#4 + 3600 > time}) then { _supportSpend = _supportSpend + _x#3 } } forEach A3A_supportSpends;

    createHashMapFromArray [
        ["active", [gameMode != 3, gameMode != 4] select _isOcc],
        ["defRes", [A3A_resourcesDefenceInv, A3A_resourcesDefenceOcc] select _isOcc],
        ["atkRes", [A3A_resourcesAttackInv, A3A_resourcesAttackOcc] select _isOcc],
        ["rates", +([A3A_resourceRatesInv, A3A_resourceRatesOcc] select _isOcc)],
        ["aggression", [aggressionInvaders, aggressionOccupants] select _isOcc],
        ["aggressionLevel", [aggressionLevelInvaders, aggressionLevelOccupants] select _isOcc],
        ["aggressionEvents", count ([aggressionStackInvaders, aggressionStackOccupants] select _isOcc)],
        ["damageEvents", count _damageEvents],
        ["damageValue", _damageValue],
        ["hqKnowledge", [A3A_curHQInfoInv, A3A_curHQInfoOcc] select _isOcc],
        ["sites", _sites],
        ["troops", [_troops, _troopsMax]],
        ["vehicles", _vehicles],
        ["police", [_police, _policeMax]],
        ["strikes", {_x#0 == _side && {_x#3 > time}} count A3A_supportStrikes],
        ["supports", {_x#1 == _side} count A3A_activeSupports],
        ["supportSpend", _supportSpend]
    ];
};

["dataReceived", [_global, _sides]] remoteExecCall ["A3A_GUI_fnc_factionDebugTab", _client];
