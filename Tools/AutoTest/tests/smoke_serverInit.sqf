// @description: Server init completes on a new game and the core state exists
// @timeout: 60
// @start: new
// @world: Altis
#include "\x\A3A_autotest\test.hpp"

ASSERT(!isNil "serverInitDone", "serverInitDone is set");
ASSERT_EQ(A3A_startupState, "completed", "startup state");
ASSERT(!isNil "A3A_saveTarget", "save target exists");

ASSERT(!isNil "petros" && {alive petros}, "Petros exists and is alive");
private _hqDistance = petros distance2D markerPos "Synd_HQ";
ASSERT(_hqDistance < 100, "Petros stands at the HQ marker");

{
    private _faction = missionNamespace getVariable _x;
    private _loaded = !isNil "_faction" && {_faction isEqualType createHashMap};
    [_loaded, _x + " is loaded"] call A3A_test_fnc_assert;
} forEach ["A3A_faction_occ", "A3A_faction_inv", "A3A_faction_reb", "A3A_faction_civ"];

private _names = [A3A_faction_occ, A3A_faction_inv, A3A_faction_reb] apply { _x get "name" };
INFO("Factions occ/inv/reb: " + (_names joinString " / "));
