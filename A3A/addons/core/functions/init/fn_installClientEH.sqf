player addEventHandler ["FiredMan", A3A_fnc_rebelFiredManEH];

player addEventHandler ["InventoryOpened", {
    private ["_playerX","_containerX","_typeX"];
    _control = false;
    _playerX = _this select 0;
    if !(captive _playerX) exitWith {false};

    _containerX = _this select 1;
    _typeX = typeOf _containerX;
    if (((_containerX isKindOf "Man") and (!alive _containerX)) or (_typeX in [A3A_faction_occ get "ammobox", A3A_faction_inv get "ammobox"])) then {
        if ({if (((side _x== Invaders) or (side _x== Occupants)) and (_x knowsAbout _playerX > 1.4)) exitWith {1}} count allUnits > 0) then{
            _playerX setCaptive false;
        }
        else {
            _city = [citiesX,_playerX] call BIS_fnc_nearestPosition;
            _size = [_city] call A3A_fnc_sizeMarker;
            _cityData = A3A_cityData getVariable _city;
            if (random 100 > _cityData select 1) then {            // reb support
                if (_playerX distance getMarkerPos _city < _size * 1.5) then {
                    _playerX setCaptive false;
                };
            };
        };
    };
    _control
}];
/*
player addEventHandler ["InventoryClosed", {
    _control = false;
    _uniform = uniform player;
    _typeSoldier = getText (configfile >> "CfgWeapons" >> _uniform >> "ItemInfo" >> "uniformClass");
    _sideType = getNumber (configfile >> "CfgVehicles" >> _typeSoldier >> "side");
    if ((_sideType == 1) or (_sideType == 0) and (_uniform != "")) then {
        if !(player getVariable ["disguised",false]) then {
            hint "You are wearing an enemy uniform, this will make the AI attack you. Beware!";
            player setVariable ["disguised",true];
            player addRating (-1*(2001 + rating player));
        };
    }
    else {
        if (player getVariable ["disguised",false]) then {
            hint "You removed your enemy uniform";
            player addRating (rating player * -1);
        };
    };
    _control
}];
*/
player addEventHandler ["HandleHeal", {
    _player = _this select 0;
    if (captive _player) then {
        if ({((side _x== Invaders) or (side _x== Occupants)) and (_x knowsAbout player > 1.4)} count allUnits > 0) then {
            _player setCaptive false;
        }
        else {
            _city = [citiesX,_player] call BIS_fnc_nearestPosition;
            _size = [_city] call A3A_fnc_sizeMarker;
            _cityData = A3A_cityData getVariable _city;
            if (random 100 > _cityData select 1) then {            // reb support
                if (_player distance getMarkerPos _city < _size * 1.5) then {
                    _player setCaptive false;
                };
            };
        };
    };
}];

// notes:
// Static weapon objects are persistent through assembly/disassembly
// The bags are not persistent, object IDs change each time
// Static weapon position seems to follow bag1, but it's not an attached object
// Can use objectParent to identify backpack of static weapon

player addEventHandler ["WeaponAssembled", {
    private _veh = _this select 1;
    [_veh, teamPlayer] call A3A_fnc_AIVEHinit;		// will flip/capture if already initialized
    if !(_veh isKindOf "StaticWeapon") exitWith {};         // Don't auto-garrison drones
    private _marker = [getPosATL _veh] call A3A_fnc_getMarkerForPos;
    if (_marker != "") then {
        [_marker, _veh] remoteExecCall ["A3A_fnc_garrisonServer_addVehicle", 2];
        [localize "STR_A3A_fn_proxy_statDepl_titel", localize "STR_A3A_fn_proxy_statDepl_text"] call A3A_fnc_customHint;
    };
}];

player addEventHandler ["WeaponDisassembled", {
    params ["", "_bag1", "_bag2", "_veh"];
    [objectParent _bag1] remoteExec ["A3A_fnc_postmortem", 2];      // hmm, are these really 
    [objectParent _bag2] remoteExec ["A3A_fnc_postmortem", 2];
    private _marker = _veh getVariable ["markerX", ""];
    if (_marker != "") then {
        [_veh] remoteExecCall ["A3A_fnc_garrisonServer_remVehicle", 2];
    };
}];


// Actions dont persist across respawns so they're temporarily stuck here

// allow player to open any nearby helipads
player addAction ["Open Heli Garage", 
"
        if ([getPosATL player] call A3A_fnc_enemyNearCheck) exitWith {[localize 'STR_A3A_fn_init_initclient_helipad',localize 'STR_A3A_fn_init_initclient_helipad_enemies'] call A3A_fnc_customHint};
        _helipad = (nearestObjects [player, ['a3a_helipad'], 8, true])#0;
        HR_GRG_accessPoint = _helipad;
        HR_GRG_accessLimit = 'helipad';
        createDialog 'HR_GRG_VehicleSelect';
", nil, 4, true, true, "","(count (nearestObjects [player, ['a3a_helipad'], 8, true]) > 0) && {((isNil 'HR_GRG_Placing') || {!HR_GRG_Placing}) && player isEqualTo vehicle player && _this == _this getVariable ['owner',objNull]}"
];

// Commander rally flag self-actions. Anyone can teleport to the flag from the HQ flag (see initClient).
// Removal is always available, but only while looking at the deployed flag from close by.
player addAction [localize "STR_A3A_fn_init_installClientEH_deployFlag", {
    private _remaining = if (isNull A3A_deployedFlag) then { 0 } else { A3A_deployedFlagCooldown - (serverTime - A3A_deployedFlagTime) };
    if (_remaining > 0) exitWith {
        private _prettyTime = [_remaining,1,1,false,2,false,true] call A3A_fnc_timeSpan_format;
        [localize "STR_A3A_fn_base_deployedFlag_title", format [localize "STR_A3A_fn_init_installClientEH_deployFlag_cooldown", _prettyTime]] call A3A_fnc_customHint;
    };
    [player] remoteExecCall ["A3A_fnc_deployedFlagPlace", 2];
}, nil, 0, false, true, "", "(_this == theBoss) and !A3A_petrosMoving and (vehicle _this == _this) and (_this == _this getVariable ['owner',objNull])"];

player addAction [localize "STR_A3A_fn_init_installClientEH_removeFlag", {
    [player] remoteExecCall ["A3A_fnc_deployedFlagRemove", 2];
}, nil, 0, false, true, "", "(_this == theBoss) and !isNull A3A_deployedFlag and (cursorObject == A3A_deployedFlag) and (_this distance A3A_deployedFlag < 10)"];