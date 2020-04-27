if (count hcSelected player == 0) exitWith {["Artillery Support", "You must select an artillery group"] call A3A_fnc_customHint;};

private ["_groups","_artyArray","_artyRoundsArr","_hasAmmunition","_areReady","_hasArtillery","_areAlive","_soldierX","_veh","_typeAmmunition","_typeArty","_positionTel","_artyArrayDef1","_artyRoundsArr1","_piece","_isInRange","_positionTel2","_rounds","_roundsMax","_markerX","_size","_forcedX","_textX","_mrkFinal","_mrkFinal2","_timeX","_eta","_countX","_pos","_ang"];

// AGN_MortarUsage zawiera (dany obiekt) [ jednostke, kiedy_moze_strzelic ]
if (isnil "AGN_MortarUsage") then
{
	AGN_MortarUsage = [];
	publicVariable "AGN_MortarUsage";
};

_groups = hcSelected player;
_unitsX = [];
{_groupX = _x;
{_unitsX pushBack _x} forEach units _groupX;
} forEach _groups;
typeAmmunition = nil;
_artyArray = [];
_artyRoundsArr = [];

_hasAmmunition = 0;
_areReady = false;
_hasArtillery = false;
_areAlive = false;
_shootingTimeout = false;
_waitTime = "";

{
_soldierX = _x;
_veh = vehicle _soldierX;
if ((_veh != _soldierX) and (not(_veh in _artyArray))) then
	{
	if (( "Artillery" in (getArray (configfile >> "CfgVehicles" >> typeOf _veh >> "availableForSupportTypes")))) then
		{
		_hasArtillery = true;
		if ((canFire _veh) and (alive _veh) and (isNil "typeAmmunition")) then
			{
			_areAlive = true;
			_nul = createDialog "mortar_type";
			waitUntil {!dialog or !(isNil "typeAmmunition")};
			if !(isNil "typeAmmunition") then
				{
				_typeAmmunition = typeAmmunition;
				//typeAmmunition = nil;
			//	};
			//if (! isNil "_typeAmmunition") then
				//{
				{
				if (_x select 0 == _typeAmmunition) then
					{
					_hasAmmunition = _hasAmmunition + 1;
					};
				} forEach magazinesAmmo _veh;
				};
			if (_hasAmmunition > 0) then
				{
				if (unitReady _veh) then
					{
						_hasTimeout = false;
						{
							if ((_x select 0) == _veh && ((_x select 1) > time)) then
							{
								_hasTimeout = true;
								_shootingTimeout = true;
								_test = (_x select 1) - time;
								_test = round _test;
								_waittime = Format ["You need to wait %1 s", _test];
							}

						} foreach AGN_MortarUsage;
						if(!_hasTimeout) then
						{
							_areReady = true;
							_artyArray pushBack _veh;
							_artyRoundsArr pushBack (((magazinesAmmo _veh) select 0)select 1);
						}
					};
				};
			};
		};
	};
} forEach _unitsX;

if (!_hasArtillery) exitWith {["Artillery Support", "You must select an artillery group or it is a Mobile Mortar and it's moving"] call A3A_fnc_customHint;};
if (!_areAlive) exitWith {["Artillery Support", "All elements in this Batery cannot fire or are disabled"] call A3A_fnc_customHint;};
if ((_hasAmmunition < 2) and (!_areReady)) exitWith {["Artillery Support", "The Battery has no ammo to fire. Reload it on HQ"] call A3A_fnc_customHint;};
if (_shootingTimeout and count _artyArray == 0) exitWith {
	["Artillery Support", Format[ "All mortars have timeout. %1", _waitTime]] call A3A_fnc_customHint;
};
if(_shootingTimeout) then {
	["Artillery Support", Format[ "At least 1 mortar has timeout. %1", _waitTime]] call A3A_fnc_customHint;
};
if (!_areReady) exitWith {["Artillery Support", "Selected Battery is busy right now"] call A3A_fnc_customHint;};
if (_typeAmmunition == "not_supported") exitWith {["Artillery Support", "Your current modset doesent support this strike type"] call A3A_fnc_customHint;};
if (isNil "_typeAmmunition") exitWith {};

hcShowBar false;
hcShowBar true;

if (_typeAmmunition != "2Rnd_155mm_Mo_LG") then
	{
	closedialog 0;
	_nul = createDialog "strike_type";
	}
else
	{
	typeArty = "NORMAL";
	};

waitUntil {!dialog or (!isNil "typeArty")};

if (isNil "typeArty") exitWith {};

_typeArty = typeArty;
typeArty = nil;


positionTel = [];

["Artillery Support", "Select the position on map where to perform the Artillery strike"] call A3A_fnc_customHint;

if (!visibleMap) then {openMap true};
onMapSingleClick "positionTel = _pos;";

waitUntil {sleep 1; (count positionTel > 0) or (!visibleMap)};
onMapSingleClick "";

if (!visibleMap) exitWith {};

_positionTel = positionTel;

_artyArrayDef1 = [];
_artyRoundsArr1 = [];

for "_i" from 0 to (count _artyArray) - 1 do
	{
	_piece = _artyArray select _i;
	_isInRange = _positionTel inRangeOfArtillery [[_piece], ((getArtilleryAmmo [_piece]) select 0)];
	if (_isInRange) then
		{
		_artyArrayDef1 pushBack _piece;
		_artyRoundsArr1 pushBack (_artyRoundsArr select _i);
		};
	};

if (count _artyArrayDef1 == 0) exitWith {["Artillery Support", "The position you marked is out of bounds for that Battery"] call A3A_fnc_customHint;};

_mrkFinal = createMarkerLocal [format ["Arty%1", random 100], _positionTel];
_mrkFinal setMarkerShapeLocal "ICON";
_mrkFinal setMarkerTypeLocal "hd_destroy";
_mrkFinal setMarkerColorLocal "ColorRed";

if (_typeArty == "BARRAGE") then
	{
	_mrkFinal setMarkerTextLocal "Atry Barrage Begin";
	positionTel = [];

	["Artillery Support", "Select the position to finish the barrage"] call A3A_fnc_customHint;

	if (!visibleMap) then {openMap true};
	onMapSingleClick "positionTel = _pos;";

	waitUntil {sleep 1; (count positionTel > 0) or (!visibleMap)};
	onMapSingleClick "";

	_positionTel2 = positionTel;
	};

if ((_typeArty == "BARRAGE") and (isNil "_positionTel2")) exitWith {deleteMarkerLocal _mrkFinal};

if (_typeArty != "BARRAGE") then
	{
	if (_typeAmmunition != "2Rnd_155mm_Mo_LG") then
		{
		closedialog 0;
		_nul = createDialog "rounds_number";
		}
	else
		{
		roundsX = 1;
		};
	waitUntil {!dialog or (!isNil "roundsX")};
	};

if ((isNil "roundsX") and (_typeArty != "BARRAGE")) exitWith {deleteMarkerLocal _mrkFinal};

if (_typeArty != "BARRAGE") then
	{
	_mrkFinal setMarkerTextLocal "Arty Strike";
	_rounds = roundsX;
	_roundsMax = _rounds;
	roundsX = nil;
	}
else
	{
	_rounds = round (_positionTel distance _positionTel2) / 10;
	_roundsMax = _rounds;
	};

_markerX = [markersX,_positionTel] call BIS_fnc_nearestPosition;
_size = [_markerX] call A3A_fnc_sizeMarker;
_forcedX = false;

if ((not(_markerX in forcedSpawn)) and (_positionTel distance (getMarkerPos _markerX) < _size) and ((spawner getVariable _markerX != 0))) then
	{
	_forcedX = true;
	forcedSpawn pushBack _markerX;
	publicVariable "forcedSpawn";
	};

_textX = format ["Requesting fire support on Grid %1. %2 Rounds", mapGridPosition _positionTel, round _rounds];
[theBoss,"sideChat",_textX] remoteExec ["A3A_fnc_commsMP",[teamPlayer,civilian]];

if (_typeArty == "BARRAGE") then
	{
	_mrkFinal2 = createMarkerLocal [format ["Arty%1", random 100], _positionTel2];
	_mrkFinal2 setMarkerShapeLocal "ICON";
	_mrkFinal2 setMarkerTypeLocal "hd_destroy";
	_mrkFinal2 setMarkerColorLocal "ColorRed";
	_mrkFinal2 setMarkerTextLocal "Arty Barrage End";
	_ang = [_positionTel,_positionTel2] call BIS_fnc_dirTo;
	sleep 5;
	_eta = (_artyArrayDef1 select 0) getArtilleryETA [_positionTel, ((getArtilleryAmmo [(_artyArrayDef1 select 0)]) select 0)];
	_timeX = time + _eta;
	_textX = format ["Acknowledged. Fire mission is inbound. ETA %1 secs for the first impact",round _eta];
	[petros,"sideChat",_textX]remoteExec ["A3A_fnc_commsMP",[teamPlayer,civilian]];
	[_timeX] spawn
		{
		private ["_timeX"];
		_timeX = _this select 0;
		waitUntil {sleep 1; time > _timeX};
		[petros,"sideChat","Splash. Out"] remoteExec ["A3A_fnc_commsMP",[teamPlayer,civilian]];
		};
	};

_pos = [_positionTel,random 10,random 360] call BIS_fnc_relPos;

for "_i" from 0 to (count _artyArrayDef1) - 1 do
	{
	if (_rounds > 0) then
		{
		_piece = _artyArrayDef1 select _i;
		_countX = _artyRoundsArr1 select _i;
		_distance = _positionTel distance _piece;
		//hint format ["roundsX que faltan: %1, roundsX que tiene %2",_rounds,_countX];

		// tutaj dodamy pieze (artylerie?) do naszego AGN_MortarUsage
		//najpierw sprawdzmy czy istnieje i zupdatujemy jesli tak
		_updated = false;
		for "_j" from 0 to (count AGN_MortarUsage) - 1 do
		{
			_val = AGN_MortarUsage select _j;
			if((_val select 0) == _piece) then {
				AGN_MortarUsage set [_j, [_piece, time + _rounds * 120]];
				_updated = true;
			};
		};
		// If it does not exist we need to add it.
		if (!_updated) then {
				AGN_MortarUsage pushBack [_piece, time + _rounds * 120];
		};

		if (_countX >= _rounds) then
			{
			if (_typeArty != "BARRAGE") then
				{
				_firePos =  [_pos,random (35 + _distance / 100),random 360] call BIS_fnc_relPos;
				_piece commandArtilleryFire [_firepos,_typeAmmunition,_rounds];
				}
			else
				{
				for "_r" from 1 to _rounds do
					{
					_firePos =  [_pos,random (35 + _distance / 100),random 360] call BIS_fnc_relPos;
					_piece commandArtilleryFire [_firePos,_typeAmmunition,1];
					sleep 2;
					_pos = [_pos,10,_ang + 5 - (random 10)] call BIS_fnc_relPos;
					};
				};
			_rounds = 0;
			}
		else
			{
			if (_typeArty != "BARRAGE") then
				{
				_firePos =  [_pos,random (35 + _distance / 100),random 360] call BIS_fnc_relPos;
				_piece commandArtilleryFire [[_firePos,random 10,random 360] call BIS_fnc_relPos,_typeAmmunition,_countX];
				}
			else
				{
				for "_r" from 1 to _countX do
					{
					_firePos =  [_pos,random (35 + _distance / 100),random 360] call BIS_fnc_relPos;
					_piece commandArtilleryFire [_firePos,_typeAmmunition,1];
					sleep 2;
					_pos = [_pos,10,_ang + 5 - (random 10)] call BIS_fnc_relPos;
					};
				};
			_rounds = _rounds - _countX;
			};
		};
	};

if (_typeArty != "BARRAGE") then
	{
	sleep 5;
	_eta = (_artyArrayDef1 select 0) getArtilleryETA [_positionTel, ((getArtilleryAmmo [(_artyArrayDef1 select 0)]) select 0)];
	_timeX = time + _eta - 5;
	if (isNil "_timeX") exitWith {
		diag_log format ["%1: [Antistasi] | ERROR | ArtySupport.sqf | Params: %2,%3,%4,%5",servertime,_artyArrayDef1 select 0,_positionTel,((getArtilleryAmmo [(_artyArrayDef1 select 0)]) select 0),(_artyArrayDef1 select 0) getArtilleryETA [_positionTel, ((getArtilleryAmmo [(_artyArrayDef1 select 0)]) select 0)]];
		};
	_textX = format ["Acknowledged. Fire mission is inbound. %2 Rounds fired. ETA %1 secs",round _eta,_roundsMax - _rounds];
	[petros,"sideChat",_textX] remoteExec ["A3A_fnc_commsMP",[teamPlayer,civilian]];
	};

if (_typeArty != "BARRAGE") then
	{
	waitUntil {sleep 1; time > _timeX};
	[petros,"sideChat","Splash. Out"] remoteExec ["A3A_fnc_commsMP",[teamPlayer,civilian]];
	};
sleep 10;
deleteMarkerLocal _mrkFinal;
if (_typeArty == "BARRAGE") then {deleteMarkerLocal _mrkFinal2};

if (_forcedX) then
	{
	sleep 20;
	if (_markerX in forcedSpawn) then
		{
		forcedSpawn = forcedSpawn - [_markerX];
		publicVariable "forcedSpawn";
		};
	};
