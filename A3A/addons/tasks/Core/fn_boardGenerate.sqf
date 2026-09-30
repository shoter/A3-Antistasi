/*
Maintainer: Shoter
    Creates one mission board entry of the given category.
    Every task of the category gets a few calls of its params getter to find a location that is not
    on the board already for that task (no two supply runs to the same town), then one task is picked
    by the weights the getters return. The hard variant, convoy type and defector money are rolled
    here, so the board can show the exact reward before anyone takes the mission.

Arguments:
    <STRING> Category: "AS", "CONVOY", "DES", "CON", "LOG", "SUPP" or "RES"

Return Value:
    <HASHMAP> Board entry, or <BOOL> false when no mission of that category fits right now
        "id"        <NUMBER> unique id, clients refer to the entry by it
        "task"      <STRING> task class name from configFile >> "A3A" >> "Tasks"
        "category"  <STRING> category, as above
        "key"       <STRING> task + location, unique on the board
        "marker"    <STRING> location marker shown in the Location column
        "origin"    <STRING> convoy start marker, "" for other tasks
        "name"      <STRING> stringtable key of the mission name
        "hard"      <BOOL> hard variant
        "args"      <ARRAY> arguments the task function is started with
        "legacy"    <BOOL> spawned directly rather than through A3A_tasks_fnc_runTask
        "func"      <STRING> task function name
        "reward"    <ARRAY> see A3A_tasks_fnc_boardReward

Scope: Server
Environment: Scheduled
Public: No

Example:
    ["RES"] call A3A_tasks_fnc_boardGenerate;
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

#define TASKS_CFG (configFile/"A3A"/"Tasks")
#define PARAMS_TRIES 3

params ["_category"];

private _takenKeys = A3A_missionBoard apply { _x get "key" };
private _candidates = [];
private _weights = [];

{
    private _cfg = _x;
    if (getText (_cfg >> "category") != _category) then { continue };
    private _taskName = configName _cfg;

    private _paramsFncName = getText (_cfg >> "params");
    private _paramsFnc = missionNamespace getVariable _paramsFncName;
    if (isNil "_paramsFnc") then {
        Error_1("No function %1 found", _paramsFncName);
        continue;
    };
    if (isNil { missionNamespace getVariable getText (_cfg >> "func") }) then {
        Error_1("No task function found for %1", _taskName);
        continue;
    };

    // Getters pick a random location, so a few calls usually find one that is not on the board yet
    for "_i" from 1 to PARAMS_TRIES do {
        private _result = call _paramsFnc;
        if (_result isEqualType false) exitWith {};             // no valid location at all
        _result params ["_weight", "_params"];
        private _marker = _params # 0;
        if (_marker isEqualType []) then { _marker = [citiesX, _marker] call BIS_fnc_nearestPosition };     // bank and weapons truck give a position
        private _key = _taskName + "|" + _marker;
        if (_key in _takenKeys) then { continue };
        _candidates pushBack [_cfg, _params, _marker, _key];
        _weights pushBack (_weight max 0.01);
        break;
    };
} forEach ("true" configClasses TASKS_CFG);

if (_candidates isEqualTo []) exitWith { false };

(_candidates selectRandomWeighted _weights) params ["_cfg", "_params", "_marker", "_key"];
private _taskName = configName _cfg;

private _args = +_params;
private _hard = false;
private _extra = "";
private _origin = "";
private _nameKey = getText (_cfg >> "boardName");

if (_taskName == "convoy") then {
    _params params ["_mrkDest", "_mrkOrigin"];
    _hard = random 10 < tierWar;
    // Same choice A3A_fnc_convoy makes from the destination
    private _convoyTypes = call {
        if (_mrkDest in airportsX or _mrkDest in outposts) exitWith { ["Ammunition", "Armor"] };
        if (_mrkDest in citiesX) exitWith { ["Supplies"] };
        if (_mrkDest in resourcesX or _mrkDest in factories) exitWith { ["Money"] };
        ["Prisoners"];
    };
    _extra = selectRandom _convoyTypes;
    _nameKey = switch (_extra) do {
        case "Ammunition": { "STR_A3A_fn_mission_conv_ammo_titel" };
        case "Armor": { "STR_A3A_fn_mission_conv_armor_titel" };
        case "Money": { "STR_A3A_fn_mission_conv_money_titel" };
        case "Supplies": { "STR_A3A_fn_mission_conv_supply_titel" };
        default { "STR_A3A_fn_mission_conv_prison_titel" };
    };
    _origin = _mrkOrigin;
    _args = [_mrkDest, _mrkOrigin, _extra, "legacy", -1, [], _hard];
};

if (_taskName == "RES_Defector") then {
    _extra = 2000 + 100 * floor random 41;          // 2000-6000
    _args pushBack _extra;
};

if (getNumber (_cfg >> "boardDifficulty") > 0) then {
    _hard = random 10 < tierWar;
    _args pushBack _hard;                           // legacy missions read it as the param after their own
};

A3A_missionBoardUID = A3A_missionBoardUID + 1;

createHashMapFromArray [
    ["id", A3A_missionBoardUID],
    ["task", _taskName],
    ["category", _category],
    ["key", _key],
    ["marker", _marker],
    ["origin", _origin],
    ["name", _nameKey],
    ["hard", _hard],
    ["args", _args],
    ["legacy", getNumber (_cfg >> "isLegacy") != 0],
    ["func", getText (_cfg >> "func")],
    ["reward", [_taskName, _hard, _extra] call FUNC(boardReward)]
];
