/*
Maintainer: Shoter
    Server loop for the junkyard: restocks every A3A_junkyardRefreshInterval seconds of server uptime
    and clears expired junk status every 5 minutes. A new campaign (no scheduled delivery yet) is stocked immediately.

Arguments:
    None

Return Value:
    <nil>

Scope: Server
Environment: Scheduled
Public: No
Dependencies: A3A_fnc_junkyardRefresh, A3A_fnc_junkyardExpire

Example:
    [] spawn A3A_fnc_junkyardLoop;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if !(isServer) exitWith { Error("Attempted to call server function as non-server") };

if (A3A_junkyardNextRefresh < 0) then { call A3A_fnc_junkyardRefresh };

private _nextExpireCheck = 0;
while {true} do {
    sleep 30;
    if (serverTime >= A3A_junkyardNextRefresh) then { call A3A_fnc_junkyardRefresh };
    if (serverTime >= _nextExpireCheck) then {
        _nextExpireCheck = serverTime + 300;
        call A3A_fnc_junkyardExpire;
    };
};
