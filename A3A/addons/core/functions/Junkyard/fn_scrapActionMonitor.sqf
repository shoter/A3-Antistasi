/*
Maintainer: Shoter
    Client loop that offers the "Strip for scrap" hold action on wrecks. Instead of adding an action to every dead
    vehicle on every client, it watches cursorObject once a second and adds the hold action locally the first time
    the player looks at a wreck. The action shows for engineers with a toolkit while the wreck may be stripped
    (see A3A_fnc_scrapCanStrip) and hides once anyone has stripped it.

Arguments:
    None

Return Value:
    <nil>

Scope: Clients
Environment: Scheduled
Public: No
Dependencies: A3A_fnc_scrapCanStrip, A3A_fnc_scrapStrip, A3A_fnc_isEngineer, A3A_fnc_canFight, A3A_scrapStripDuration

Example:
    0 spawn A3A_fnc_scrapActionMonitor;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if (!hasInterface) exitWith {};
Info("Scrapyard action monitor started");

while {true} do {
    sleep 1;
    private _wreck = cursorObject;
    if (isNull _wreck or {alive _wreck}) then { continue };
    // Same whitelist as A3A_fnc_scrapCanStrip, checked here to keep the action off statics and dead men
    if !((_wreck isKindOf "LandVehicle" or _wreck isKindOf "Air" or _wreck isKindOf "Ship") and !(_wreck isKindOf "StaticWeapon") and !(_wreck isKindOf "ParachuteBase")) then { continue };
    if (_wreck getVariable ["A3A_scrapStripped", false]) then { continue };
    if !(isNil { _wreck getVariable "A3A_scrapActionAdded" }) then { continue };

    // Local flag only: hold actions are local, every client adds its own when its player looks at the wreck
    _wreck setVariable ["A3A_scrapActionAdded", true];
    [
        _wreck,
        localize "STR_A3A_fn_junkyard_scrap_action",
        "a3\ui_f\data\igui\cfg\actions\repair_ca.paa",
        "a3\ui_f\data\igui\cfg\actions\repair_ca.paa",
        "(player call A3A_fnc_isEngineer) and {isNull objectParent player} and {player distance _target < (4 + ((boundingBoxReal _target) # 2))} and {([_target, player] call A3A_fnc_scrapCanStrip) # 0}",
        "([player] call A3A_fnc_canFight) and {player distance _target < (6 + ((boundingBoxReal _target) # 2))}",
        {},
        {},
        { [_this # 0, player] remoteExecCall ["A3A_fnc_scrapStrip", 2] },
        {},
        [],
        A3A_scrapStripDuration
    ] call BIS_fnc_holdActionAdd;
    Debug_1("Scrapyard: strip action added to %1", typeOf _wreck);
};
