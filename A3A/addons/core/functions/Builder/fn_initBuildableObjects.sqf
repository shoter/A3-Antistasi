/*
Author: [Killerswin2]
    creates the buildable object list on clients.
Arguments:
    None
Return Value:
NONE
Scope: Client
Environment: Unscheduled
Public: 
no
Example:
call A3A_fnc_initBuildableObjects;
*/

private _mapInfo = missionConfigFile/"A3A"/"mapInfo"/toLower worldName;
if (!isClass _mapInfo) then {_mapInfo = configFile/"A3A"/"mapInfo"/toLower worldName};
A3A_buildableObjects = getArray (_mapInfo/"buildObjects");

// Shared extras for every map, unless the map only wants its own era-specific objects
if (!isNumber (_mapInfo/"extraBuildObjects") || { getNumber (_mapInfo/"extraBuildObjects") != 0 }) then {
    private _extraCfg = configFile/"A3A"/"buildObjectsExtra";
    private _climateList = ["green", "arid"] select (getText (_mapInfo/"climate") == "arid");
    private _known = A3A_buildableObjects apply { toLower (_x#0) };
    {
        _x params ["_class"];
        if (toLower _class in _known) then { continue };
        if (getNumber (configFile/"CfgVehicles"/_class/"scope") < 1) then { continue };       // also skips classes that aren't loaded
        _known pushBack toLower _class;
        A3A_buildableObjects pushBack _x;
    } forEach (getArray (_extraCfg/"common") + getArray (_extraCfg/_climateList));
};

A3A_buildingPriceHM = createHashMapFromArray A3A_buildableObjects; // you can feed 3-element arrays to createHashMapFromArray, it will ignore anything after the first two for each entry

A3A_buildableObjects