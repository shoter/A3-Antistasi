/*
Maintainer: Shoter
    Tells whether a key is bound to the "Turn left" or "Turn right" Antistasi keybind (A3A_core_turnLeft,
    A3A_core_turnRight). The placement modes call it from their KeyDown and KeyUp handlers, so they can rotate while
    the key is held and block the key's normal action (lean, by default).
    Only single keyboard keys match: key combinations and mouse buttons bound to these actions are ignored.

Arguments:
    <NUMBER> DIK code of the key, as given to a KeyDown or KeyUp event handler

Return Value:
    <NUMBER> -1 for turn left, 1 for turn right, 0 for neither

Scope: Clients
Environment: Any
Public: No

Example:
    private _turn = [_key] call A3A_fnc_turnKeyDir;
*/

params ["_key"];

if (_key in actionKeys "A3A_core_turnLeft") exitWith { -1 };
if (_key in actionKeys "A3A_core_turnRight") exitWith { 1 };
0;
