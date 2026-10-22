// @description: A new campaign has map markers, enemy garrisons and starting resources
// @timeout: 60
// @start: new
// @world: Altis
#include "\x\A3A_autotest\test.hpp"

ASSERT(count citiesX > 0, "cities exist");
ASSERT(count airportsX > 0, "airports exist");
ASSERT(count outposts > 0, "outposts exist");

// Every enemy marker starts owned by an enemy side with a garrison entry
private _enemyMarkers = markersX - ["Synd_HQ"];
private _rebelOwned = _enemyMarkers select { sidesX getVariable [_x, sideUnknown] == teamPlayer };
ASSERT_EQ(_rebelOwned, [], "markers owned by rebels at campaign start");

private _noGarrison = (airportsX + outposts) select { isNil {A3A_garrison get _x} };
ASSERT_EQ(_noGarrison, [], "airports and outposts without garrison data");

private _hr = server getVariable ["hr", -1];
private _money = server getVariable ["resourcesFIA", -1];
ASSERT(_hr >= 0, "rebel HR is set");
ASSERT(_money >= 0, "rebel money is set");

private _summary = format ["%1 cities, %2 airports, %3 outposts, HR %4, money %5", count citiesX, count airportsX, count outposts, _hr, _money];
INFO(_summary);
