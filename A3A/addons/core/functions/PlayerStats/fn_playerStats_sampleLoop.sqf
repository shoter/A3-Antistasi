/*
Maintainer: Shoter
    Server loop that samples every connected player a few times a minute and accumulates the time-based statistics:
    time and distance per movement category (on foot, ground vehicle, aircraft, boat, swimming, static weapon),
    time per role (commander included), time undercover and time per weapon or vehicle in use.
    Dead bodies are skipped, so only time spent alive is counted. Teleports (fast travel, respawn) are not distance.

Arguments:
    None

Return Value:
    Nothing, never returns

Scope: Server
Environment: Scheduled
Public: No
Dependencies:
    <HASHMAP> A3A_playerStats

Example:
    [] spawn A3A_fnc_playerStats_sampleLoop;

License: APL-ND

*/

#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

// Seconds between samples, every sample adds this much to the time buckets
#define SAMPLE_INTERVAL 5
// Longer moves between two samples are teleports, not travel
#define MAX_TRAVEL_PER_SAMPLE 2000

if (!isServer) exitWith { Error("Miscalled server-only function") };
if (!isNil "A3A_playerStats_sampleLoopRunning") exitWith { Error("Player statistics sample loop is already running") };
A3A_playerStats_sampleLoopRunning = true;

// uid -> [body sampled last time, position sampled last time]
private _samples = createHashMap;

while { true } do {
    sleep SAMPLE_INTERVAL;

    {
        private _unit = _x;
        private _uid = [_unit] call A3A_fnc_playerStats_getUID;
        if (_uid == "") then { continue };
        if (!alive _unit) then { _samples deleteAt _uid; continue };

        private _stats = [_uid] call A3A_fnc_playerStats_get;
        private _body = _unit getVariable ["owner", _unit];         // the real player body carries role and money
        private _vehicle = vehicle _unit;

        // Movement category
        private _category = if (_vehicle == _unit) then {
            private _anim = toLower animationState _unit;
            if (underwater _unit || {(_anim select [1, 3]) in ["ssw", "bsw", "dve", "sdv", "bdv"]}) then { "swim" } else { "foot" };
        } else {
            switch (true) do {
                case (_vehicle isKindOf "Air"): { "air" };
                case (_vehicle isKindOf "Ship"): { "boat" };
                case (_vehicle isKindOf "StaticWeapon"): { "static" };
                default { "ground" };
            };
        };

        private _position = getPosASL _vehicle;
        private _distance = 0;
        private _last = _samples get _uid;
        if (!isNil "_last" && {(_last select 0) isEqualTo _unit}) then {
            _distance = (_last select 1) distance _position;
            if (_distance > MAX_TRAVEL_PER_SAMPLE) then { _distance = 0 };
        };
        _samples set [_uid, [_unit, _position]];

        private _movement = _stats get "movement";
        private _bucket = _movement getOrDefault [_category, [0, 0], true];
        _bucket set [0, (_bucket select 0) + SAMPLE_INTERVAL];
        _bucket set [1, (_bucket select 1) + _distance];

        // Role and undercover
        private _role = if (_body == theBoss) then { "commander" } else { _body getVariable ["A3A_Role", "rifleman"] };
        if !(_role isEqualType "") then { _role = "rifleman" };
        private _roles = _stats get "roles";
        _roles set [_role, (_roles getOrDefault [_role, 0]) + SAMPLE_INTERVAL];

        // Downed players are made captive by the revive system, that is not undercover
        if (captive _unit && {!(_unit getVariable ["incapacitated", false])}) then {
            _stats set ["undercoverTime", (_stats get "undercoverTime") + SAMPLE_INTERVAL];
        };

        // Weapon in hand, or the vehicle the player sits in
        private _weapon = [_unit] call A3A_fnc_playerStats_weaponClass;
        if (_weapon != "") then {
            [_uid, [], [], [[_weapon, [SAMPLE_INTERVAL, 0, 0, 0, 0]]]] call A3A_fnc_playerStats_add;
        };
    } forEach (allPlayers - entities "HeadlessClient_F");

    // Forget bodies of players that left
    private _onlineUIDs = allPlayers apply { [_x] call A3A_fnc_playerStats_getUID };
    { if !(_x in _onlineUIDs) then { _samples deleteAt _x } } forEach (keys _samples);
};
