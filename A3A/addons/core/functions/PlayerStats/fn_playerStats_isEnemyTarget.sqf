/*
Maintainer: Shoter
    Tells whether an object hit by a player's projectile counts as a hit for the accuracy statistics:
    a living enemy soldier, or an enemy vehicle (Antistasi-owned by the enemy, or crewed by enemy units).
    Terrain, buildings, corpses, civilians and friendlies are not hits.

Arguments:
    <OBJECT> Object the projectile hit

Return Value:
    <BOOL> true when the object is an enemy target

Scope: Any
Environment: Any
Public: No

Example:
    [_hitEntity] call A3A_fnc_playerStats_isEnemyTarget;

License: APL-ND

*/

params [["_entity", objNull, [objNull]]];

if (isNull _entity || {!alive _entity}) exitWith { false };

if (_entity isKindOf "CAManBase") exitWith { (side group _entity) in [Occupants, Invaders] };

if (_entity isKindOf "LandVehicle" || {_entity isKindOf "Air"} || {_entity isKindOf "Ship"} || {_entity isKindOf "StaticWeapon"}) exitWith {
    (_entity getVariable ["ownerSide", sideUnknown]) in [Occupants, Invaders]
    || { (crew _entity) findIf { (side group _x) in [Occupants, Invaders] } != -1 }
};

false
