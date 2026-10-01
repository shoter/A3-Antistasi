/*
Maintainer: Shoter
    World event loop. Event missions are not posted on the mission board: they show up by themselves and are
    on the map at once, like an enemy mortar team getting ready to shell a rebel place.
    Every 30 minutes, with at least one player on the server, there is a 20% chance that one event starts.
    The event is picked by weight from the classes in configFile >> "A3A" >> "EventTasks" whose params getter
    finds valid parameters; each getter also decides whether its event may run again (one mortar at a time).
    Events are not saved, and the timer starts over after a server restart.

Arguments:
    None

Return Value:
    None, runs forever

Scope: Server
Environment: Scheduled
Public: No

Example:
    [] spawn A3A_tasks_fnc_eventLoop;
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

#define EVENT_INTERVAL 1800
#define EVENT_CHANCE 0.2
#define EVENTS_CFG (configFile/"A3A"/"EventTasks")

if (!isServer) exitWith { Error("Server-only function miscalled") };

while { true } do {
    sleep EVENT_INTERVAL;

    if ((allPlayers - entities "HeadlessClient_F") isEqualTo []) then { continue };
    if (random 1 >= EVENT_CHANCE) then { continue };
    if (missionNamespace getVariable ["A3A_petrosMoving", false]) then { continue };

    private _candidates = [];
    private _weights = [];
    {
        private _paramsFnc = missionNamespace getVariable getText (_x/"params");
        if (isNil "_paramsFnc") then { Error_1("Params function missing for event %1", configName _x); continue };
        private _result = call _paramsFnc;
        if !(_result isEqualType []) then { continue };
        _result params ["_weight", "_args"];
        _candidates pushBack [_x, _args];
        _weights pushBack (_weight * getNumber (_x/"weight"));
    } forEach ("true" configClasses EVENTS_CFG);

    if (_candidates isEqualTo []) then {
        ServerDebug("Event loop: no event could start");
        continue;
    };

    (_candidates selectRandomWeighted _weights) params ["_cfg", "_args"];
    private _taskFnc = missionNamespace getVariable getText (_cfg/"func");
    private _eventName = configName _cfg;
    ServerInfo_1("Event loop: starting %1", _eventName);
    [_taskFnc, _args] spawn FUNC(runTask);
};
