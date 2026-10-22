/*
    Picks the factions the setup dialog would preselect for a new game on this map:
    loaded templates only, matching the map climate, sorted by priority with the map bonus.
    Mirrors the faction sorting in A3A_GUI_fnc_setupFactionsTab.

    Return: ARRAY - [occupants, invaders, rebels, civilians] template class names ("" when none fits)

    Maintainer: Shoter
*/
private _worldName = toLower worldName;
private _fnc_loaded = { getArray (_this/"requiredAddons") findIf { !isClass (configFile/"CfgPatches"/_x) } == -1 };

private _bySide = [[], [], [], []];
private _sideIndex = createHashMapFromArray [["Occ", 0], ["Inv", 1], ["Reb", 2], ["Civ", 3]];
{
    private _side = getText (_x/"side");
    if (_side == "") then { continue };
    private _scope = if (isNumber (_x/"scope")) then { getNumber (_x/"scope") } else { 2 };
    if (_scope < 2) then { continue };
    (_bySide select (_sideIndex get _side)) pushBack _x;
} forEach ("true" configClasses (configFile/"A3A"/"Templates"));

_bySide apply {
    private _sorted = [];
    {
        if !(_x call _fnc_loaded) then { continue };
        private _climates = getArray (_x/"climate");
        if (_climates isNotEqualTo [] && {!(A3A_climate in _climates)}) then { continue };
        private _priority = getNumber (_x/"priority") + 0.01 * _forEachIndex;
        private _maps = getArray (_x/"maps");
        if (_maps isNotEqualTo []) then { _priority = _priority + ([-2, 2] select (_worldName in _maps)) };
        _sorted pushBack [_priority, configName _x];
    } forEach _x;
    _sorted sort false;
    if (_sorted isEqualTo []) then { "" } else { _sorted#0#1 };
};
