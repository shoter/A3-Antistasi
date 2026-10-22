/*
    Starts the campaign without the setup dialog, the way an admin would from the setup screen.

    run_config.sqf keys used:
        start     - "new" or "load"
        gameID    - campaign ID to load when start is "load" (from the server profile copied by launch_tests.ps1)
        factions  - [occ, inv, reb, civ] template names for a new game; empty entries use the dialog defaults
        addonVics - addon vehicle template names for a new game
        params    - [[name, value], ...] overriding the mission params of a new game

    Return: BOOL - true when the game was started

    Maintainer: Shoter
*/
params ["_cfg"];

private _start = _cfg getOrDefault ["start", "new"];
private _saveData = createHashMap;

if (_start == "load") then {
    private _gameID = _cfg getOrDefault ["gameID", ""];
    private _saves = call A3A_fnc_collectSaveData;
    private _index = _saves findIf { (_x get "gameID") isEqualTo _gameID && (_x get "map") == worldName };
    if (_index == -1) exitWith {
        private _available = (_saves select { (_x get "map") == worldName }) apply { _x get "gameID" };
        ["FATAL", [format ["Save '%1' not found for %2. Saves in the test profile: %3", _gameID, worldName, _available]]] call A3A_test_fnc_log;
    };
    _saveData = _saves select _index;
    _saveData set ["startType", "load"];
} else {
    private _wanted = _cfg getOrDefault ["factions", []];
    private _defaults = call A3A_test_fnc_defaultFactions;
    private _factions = [];
    for "_i" from 0 to 3 do {
        private _faction = _wanted param [_i, "", [""]];
        if (_faction == "") then { _faction = _defaults select _i };
        _factions pushBack _faction;
    };

    private _bad = _factions select { _x == "" || {!isClass (configFile/"A3A"/"Templates"/_x)} };
    if (_bad isNotEqualTo []) exitWith {
        ["FATAL", [format ["Unusable factions %1 (defaults for this map and modset: %2)", _factions, _defaults]]] call A3A_test_fnc_log;
    };

    // Param defaults with the map overrides, like the setup dialog, then the run_config overrides
    private _worldName = toLower worldName;
    private _mapInfo = missionConfigFile/"A3A"/"mapInfo"/_worldName/"MapParams";
    if (!isClass _mapInfo) then { _mapInfo = configFile/"A3A"/"mapInfo"/_worldName/"MapParams" };
    private _overrides = createHashMapFromArray (_cfg getOrDefault ["params", []]);
    private _params = [];
    {
        if (getArray (_x/"texts") isEqualTo [""]) then { continue };
        private _name = configName _x;
        private _value = getNumber (_x/"default");
        private _mapValue = (_mapInfo/_name) call BIS_fnc_getCfgData;
        if (!isNil "_mapValue") then { _value = _mapValue };
        _params pushBack [_name, _overrides getOrDefault [_name, _value]];
    } forEach ("true" configClasses (configFile/"A3A"/"Params"));

    _saveData set ["startType", "new"];
    _saveData set ["name", "AutoTest " + (_cfg getOrDefault ["runId", ""])];
    _saveData set ["startPos", markerPos "Synd_HQ"];
    _saveData set ["useNewNamespace", false];
    _saveData set ["factions", _factions];
    _saveData set ["addonVics", _cfg getOrDefault ["addonVics", []]];
    _saveData set ["DLC", []];
    _saveData set ["params", _params];
};

if (isNil {_saveData get "startType"}) exitWith { false };

["PHASE", ["campaignStart", _start, _saveData getOrDefault ["gameID", ""], _saveData get "factions"]] call A3A_test_fnc_log;
[_saveData] call A3A_fnc_startGame;
true;
