/*
Maintainer: Shoter
    Shows a vehicle delivery notification to the local player, localizing the body on the client.
    The server sends stringtable keys so every client reads the message in its own language.

Arguments:
    <STRING> Stringtable key of the body text
    <ARRAY> Format arguments for the body text [DEFAULT = []]

Return Value:
    <nil>

Scope: Clients
Environment: Any
Public: No
Dependencies:

Example:
    ["STR_A3A_fn_logistics_deliverVehicle_delivered", ["Offroad", "123456"]] remoteExecCall ["A3A_fnc_deliverVehicleHint", _player];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

params [["_bodyKey", "", [""]], ["_args", [], [[]]]];
if (!hasInterface || _bodyKey == "") exitWith {};

[localize "STR_A3A_fn_logistics_deliverVehicle_title", format ([localize _bodyKey] + _args)] call A3A_fnc_customHint;
