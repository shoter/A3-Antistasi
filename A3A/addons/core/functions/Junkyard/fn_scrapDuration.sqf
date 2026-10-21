/*
Maintainer: Shoter
    Seconds a unit needs to scrap or retrieve a wreck: a random value between A3A_scrapDurationEngineerMin and
    A3A_scrapDurationEngineerMax for engineers, between A3A_scrapDurationMin and A3A_scrapDurationMax for everyone else.
    Rolled again for every job.

Arguments:
    <OBJECT> Unit doing the work

Return Value:
    <SCALAR> Seconds

Scope: Anywhere
Environment: Any
Public: No
Dependencies: A3A_fnc_isEngineer

Example:
    private _duration = [player] call A3A_fnc_scrapDuration;
*/
params [["_unit", objNull, [objNull]]];
if (_unit call A3A_fnc_isEngineer) exitWith { A3A_scrapDurationEngineerMin + random (A3A_scrapDurationEngineerMax - A3A_scrapDurationEngineerMin) };
A3A_scrapDurationMin + random (A3A_scrapDurationMax - A3A_scrapDurationMin);
