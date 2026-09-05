/*
Maintainer: Shoter
    Whether a vehicle is still a junkyard wreck, i.e. bought from the junkyard less than A3A_junkyardJunkDuration ago.
    Junk vehicles are never repaired for free by HQ or the garage.

Arguments:
    <OBJECT> Vehicle

Return Value:
    <BOOL> True while the junk status has not expired

Scope: Anywhere
Environment: Any
Public: Yes
Dependencies: A3A_fnc_junkyardClock

Example:
    if ([_vehicle] call A3A_fnc_junkyardIsJunk) then { ... };
*/
params [["_vehicle", objNull, [objNull]]];
if (isNull _vehicle) exitWith { false };
(_vehicle getVariable ["A3A_junkyardUntil", -1]) > (call A3A_fnc_junkyardClock);
