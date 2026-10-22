// @description: A rebel rifleman can be created at HQ with A3A_fnc_createUnit and cleaned up again
// @timeout: 60
// @start: new
// @world: Altis
#include "\x\A3A_autotest\test.hpp"

private _type = A3A_faction_reb get "unitRifle";
ASSERT(_type isEqualType "" && {_type != ""}, "rebel template has unitRifle");
if (isNil "_type" || {!(_type isEqualType "")}) exitWith {};

private _group = createGroup teamPlayer;
private _pos = (markerPos "Synd_HQ") getPos [15, random 360];
private _unit = [_group, _type, _pos, [], 0, "NONE"] call A3A_fnc_createUnit;

ASSERT(!isNull _unit, "unit was created");
ASSERT(alive _unit, "unit is alive");
ASSERT_EQ(side group _unit, teamPlayer, "unit side");
private _unitType = _unit getVariable ["unitType", ""];
ASSERT_EQ(_unitType, _type, "unitType variable");

private _weapon = primaryWeapon _unit;
INFO("Rifleman spawned with " + _weapon);

deleteVehicle _unit;
deleteGroup _group;
