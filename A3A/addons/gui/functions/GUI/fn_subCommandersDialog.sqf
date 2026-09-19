/*
Maintainer: Shoter
    Handles the Sub-commanders dialog of the commander: a table of the players on the server plus the sub-commanders
    who are offline, one line of controls per player with a button to designate them or to take the role away.
    The change itself is made by the server (A3A_fnc_subCommanderSet), its notice to everyone re-renders the table
    through the "update" mode, which does nothing while the dialog is closed.

Arguments:
    <STRING> Mode: "onLoad", "update" or "toggle"
    <ARRAY<ANY>> Array of params for the mode when applicable. Params for specific modes are documented in the modes.

Return Value:
    Nothing

Scope: Clients, Local Arguments, Local Effect
Environment: Scheduled for onLoad mode / Unscheduled for everything else
Public: No
Dependencies:
    A3A_subCommanders, A3A_fnc_subCommanderSet

Example:
    ["onLoad"] spawn A3A_GUI_fnc_subCommandersDialog;
    ["toggle", ["76561198000000000", true]] call A3A_GUI_fnc_subCommandersDialog;

License: APL-ND
*/

#include "..\..\dialogues\ids.inc"
#include "..\..\dialogues\defines.hpp"
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

#define ROW_HEIGHT (5 * GRID_H)

params [["_mode", "onLoad"], ["_params", []]];

private _display = findDisplay A3A_IDD_SUBCOMMANDERSDIALOG;
if (isNull _display) exitWith {};

switch (_mode) do
{
    case ("onLoad"):
    {
        ["update"] call FUNC(subCommandersDialog);
    };

    case ("update"):
    {
        private _list = _display displayCtrl A3A_IDC_SUBCOMMANDERS_LIST;
        { ctrlDelete _x } forEach allControls _list;

        // Rows are [sort rank, lower-cased name, uid, name, body]; the UID is unique so the bodies are never compared
        // Ranks: 0 commander, 1 sub-commander, 2 sub-commander who is offline, 3 everyone else
        private _rows = [];
        private _onlineUIDs = [];
        {
            private _body = _x getVariable ["owner", _x];           // different, if remote-controlling
            private _uid = _body getVariable ["A3A_playerUID", getPlayerUID _x];
            if (_uid == "" || {_uid in _onlineUIDs}) then { continue };
            if (side group _body in [Occupants, Invaders]) then { continue };
            _onlineUIDs pushBack _uid;

            private _rank = call {
                if (_body == theBoss) exitWith { 0 };
                if (_uid in A3A_subCommanders) exitWith { 1 };
                3
            };
            _rows pushBack [_rank, toLower name _body, _uid, name _body, _body];
        } forEach (allPlayers - entities "HeadlessClient_F");
        {
            if !(_x in _onlineUIDs) then { _rows pushBack [2, toLower _y, _x, _y, objNull] };
        } forEach A3A_subCommanders;
        _rows sort true;

        private _isBoss = player == theBoss;
        private _textColor = [A3A_COLOR_TEXT] call FUNC(configColorToArray);
        private _commanderColor = [A3A_COLOR_COMMANDER] call FUNC(configColorToArray);
        private _designateText = localize "STR_antistasi_dialogs_subcommanders_designate_button";
        private _removeText = localize "STR_antistasi_dialogs_subcommanders_remove_button";

        {
            _x params ["_rank", "", "_uid", "_name", "_body"];
            private _y = _forEachIndex * ROW_HEIGHT;
            private _color = [_commanderColor, A3A_COLOR_MEMBER_SQF, A3A_COLOR_TEXT_DARKER_SQF, _textColor] select _rank;
            private _role = localize (format ["STR_antistasi_dialogs_subcommanders_role_%1", ["commander", "subcommander", "subcommander_offline", "player"] select _rank]);
            private _squads = if (isNull _body) then { "-" } else { str count hcAllGroups _body };

            // Positions are relative to the list group, 6 grid units on the right are left for the scrollbar
            {
                _x params ["_class", "_xPos", "_width", "_text"];
                private _ctrl = _display ctrlCreate [_class, -1, _list];
                _ctrl ctrlSetPosition [_xPos * GRID_W, _y, _width * GRID_W, ROW_HEIGHT];
                _ctrl ctrlCommit 0;
                _ctrl ctrlSetText _text;
                _ctrl ctrlSetTextColor _color;
            } forEach [
                ["A3A_Text", 1, 54, _name],
                ["A3A_Text", 56, 34, _role],
                ["A3A_Text", 91, 10, _squads]
            ];

            // The commander has nothing to designate on their own line
            if (_rank == 0) then { continue };

            private _isSub = _rank != 3;
            private _button = _display ctrlCreate ["A3A_Button_Small", -1, _list];
            _button ctrlSetPosition [102 * GRID_W, _y + 0.5 * GRID_H, 23 * GRID_W, ROW_HEIGHT - 1 * GRID_H];
            _button ctrlCommit 0;
            _button ctrlSetText ([_designateText, _removeText] select _isSub);
            _button ctrlSetTooltip localize (["STR_antistasi_dialogs_subcommanders_designate_tooltip", "STR_antistasi_dialogs_subcommanders_remove_tooltip"] select _isSub);
            _button ctrlEnable _isBoss;
            _button setVariable ["A3A_params", [_uid, !_isSub]];
            _button ctrlAddEventHandler ["ButtonClick", {
                params ["_control"];
                // Answered by the server notice, which renders the table again
                _control ctrlEnable false;
                ["toggle", _control getVariable "A3A_params"] call A3A_GUI_fnc_subCommandersDialog;
            }];
        } forEach _rows;

        (_display displayCtrl A3A_IDC_SUBCOMMANDERS_STATUSTEXT) ctrlSetText format [localize "STR_antistasi_dialogs_subcommanders_count", count A3A_subCommanders];
    };

    case ("toggle"):
    {
        // Takes 2 parameters: <STRING> UID of the player, <BOOL> true to designate, false to take the role away
        _params params [["_uid", "", [""]], ["_assign", true, [true]]];
        if (_uid == "") exitWith {};
        if (player != theBoss) exitWith {
            [localize "STR_antistasi_dialogs_subcommanders_titlebar", localize "STR_antistasi_dialogs_main_commanderOnly"] call A3A_fnc_customHint;
        };
        [player, _uid, _assign] remoteExecCall ["A3A_fnc_subCommanderSet", 2];
    };

    default
    {
        // Log error if attempting to call a mode that doesn't exist
        Error_1("Sub-commanders dialog mode does not exist: %1", _mode);
    };
};
