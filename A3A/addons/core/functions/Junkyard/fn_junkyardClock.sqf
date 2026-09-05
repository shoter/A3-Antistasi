/*
Maintainer: Shoter
    Campaign clock in seconds: server uptime accumulated across restarts.
    Used for junk vehicle expiry so a deadline stored on a vehicle, in a garage record or in a garrison save
    stays valid after a server restart. The offset is saved with the campaign.

Arguments:
    None

Return Value:
    <SCALAR> Seconds of campaign uptime

Scope: Anywhere
Environment: Any
Public: Yes
Dependencies: A3A_junkyardClockOffset

Example:
    private _now = call A3A_fnc_junkyardClock;
*/
(missionNamespace getVariable ["A3A_junkyardClockOffset", 0]) + serverTime;
