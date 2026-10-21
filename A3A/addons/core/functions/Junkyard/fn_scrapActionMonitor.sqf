/*
Maintainer: Shoter
    Client loop that offers "Scrap wreck" and "Retrieve wreck for repair" in the action menu of wrecks. Instead of
    adding actions to every dead vehicle on every client, it watches cursorObject once a second and adds the actions
    locally the first time the player looks at a wreck. They show for every player while the wreck may be
    worked on (see A3A_fnc_scrapCanStrip) and the player is not already working on one. Retrieve only shows for
    vehicles the junkyard repair shop can sell. Picking one starts A3A_fnc_scrapWork.

Arguments:
    None

Return Value:
    <nil>

Scope: Clients
Environment: Scheduled
Public: No
Dependencies: A3A_fnc_scrapCanStrip, A3A_fnc_scrapWork, HR_GRG_fnc_getCatIndex

Example:
    0 spawn A3A_fnc_scrapActionMonitor;
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if (!hasInterface) exitWith {};
Info("Scrapyard action monitor started");

private _condition = "!(player getVariable ['A3A_scrapWorking', false]) and {isNull objectParent player}"
    + " and {player distance _target < (4 + ((boundingBoxReal _target) # 2))} and {([_target, player] call A3A_fnc_scrapCanStrip) # 0}";

while {true} do {
    sleep 1;
    private _wreck = cursorObject;
    if (isNull _wreck or {alive _wreck}) then { continue };
    // Same whitelist as A3A_fnc_scrapCanStrip, checked here to keep the actions off statics and dead men
    if !((_wreck isKindOf "LandVehicle" or _wreck isKindOf "Air" or _wreck isKindOf "Ship") and !(_wreck isKindOf "StaticWeapon") and !(_wreck isKindOf "ParachuteBase")) then { continue };
    if (_wreck getVariable ["A3A_scrapStripped", false]) then { continue };
    if !(isNil { _wreck getVariable "A3A_scrapActionAdded" }) then { continue };

    // Local flags only: actions are local, every client adds its own when its player looks at the wreck.
    // Repairable uses the garage rules of the repair shop; the server also checks the DLC and refuses the rest.
    private _catIndex = [typeOf _wreck] call HR_GRG_fnc_getCatIndex;
    _wreck setVariable ["A3A_scrapRepairable", _catIndex >= 0 and _catIndex != 7];
    _wreck setVariable ["A3A_scrapActionAdded", true];

    _wreck addAction [
        localize "STR_A3A_fn_junkyard_scrap_action",
        { params ["_target", "", "", "_mode"]; [_target, _mode] spawn A3A_fnc_scrapWork },
        "scrap", 1.5, false, true, "", _condition, 50
    ];
    _wreck addAction [
        localize "STR_A3A_fn_junkyard_retrieve_action",
        { params ["_target", "", "", "_mode"]; [_target, _mode] spawn A3A_fnc_scrapWork },
        "retrieve", 1.49, false, true, "", _condition + " and {_target getVariable ['A3A_scrapRepairable', false]}", 50
    ];
    Debug_1("Scrapyard: actions added to %1", typeOf _wreck);
};
