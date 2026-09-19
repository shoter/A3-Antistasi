/*
Maintainer: Shoter
    Client side of the sub-commander messages, localized here rather than on the server.
    "assigned" and "removed" go to everyone: the player concerned gets an explanation of the role, the others a short note.
    "spent" goes to the commander when a sub-commander used faction resources.
    The top bar and an open Sub-commanders dialog are refreshed along the way.

Arguments:
    <STRING> Event: "assigned", "removed" or "spent"
    <ARRAY> Event params
        "assigned" / "removed": [uid, player name, commander name]
        "spent": [player name, what was bought, faction money, HR]

Return Value:
    <nil>

Scope: Clients
Environment: Any
Public: No
Dependencies:
    A3A_fnc_customHint, A3A_fnc_statistics, A3A_GUI_fnc_subCommandersDialog

Example:
    ["assigned", [_uid, _name, name _commander]] remoteExecCall ["A3A_fnc_subCommanderNotify", 0];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if (!hasInterface) exitWith {};
params [["_event", "", [""]], ["_params", [], [[]]]];

private _titleStr = localize "STR_A3A_fn_orgp_subCommander_title";

switch (_event) do {
    case "assigned";
    case "removed": {
        _params params [["_uid", "", [""]], ["_name", "", [""]], ["_commanderName", "", [""]]];
        private _isMe = _uid == getPlayerUID player;
        private _key = if (_event == "assigned") then {
            ["STR_A3A_fn_orgp_subCommander_assigned", "STR_A3A_fn_orgp_subCommander_assignedYou"] select _isMe
        } else {
            ["STR_A3A_fn_orgp_subCommander_removed", "STR_A3A_fn_orgp_subCommander_removedYou"] select _isMe
        };
        [_titleStr, format [localize _key, _name, _commanderName]] call A3A_fnc_customHint;

        // Faction money is only on the top bar of the command staff
        if (_isMe) then { [] spawn A3A_fnc_statistics };
        ["update"] call A3A_GUI_fnc_subCommandersDialog;
    };

    case "spent": {
        _params params [["_name", "", [""]], ["_item", "", [""]], ["_money", 0, [0]], ["_hr", 0, [0]]];
        private _key = ["STR_A3A_fn_orgp_subCommander_spent", "STR_A3A_fn_orgp_subCommander_spentHr"] select (_hr > 0);
        [_titleStr, format [localize _key, _name, _item, round _money, _hr]] call A3A_fnc_customHint;
    };

    default { Error_1("Unknown sub-commander event: %1", _event) };
};
