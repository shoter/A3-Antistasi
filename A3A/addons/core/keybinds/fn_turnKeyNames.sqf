/*
Maintainer: Shoter
    Names of the keys bound to the "Turn left" and "Turn right" Antistasi keybinds, for the placement hints.
    Gives the first key of each, or "-" when nothing is bound.

Arguments:
    None

Return Value:
    <ARRAY<STRING>> [turn left key name, turn right key name]

Scope: Clients
Environment: Any
Public: No

Example:
    (call A3A_fnc_turnKeyNames) params ["_leftKey", "_rightKey"];
*/

["A3A_core_turnLeft", "A3A_core_turnRight"] apply {
    // actionKeysNames quotes the name, e.g. "Q" with the quotes
    private _name = actionKeysNames [_x, 1];
    if (count _name < 3) then { "-" } else { _name select [1, count _name - 2] };
};
