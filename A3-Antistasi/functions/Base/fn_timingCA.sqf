/**
	Changes time of the timer for the next counter attack.
	Counter attack is automatically synchronized to every player after this method is executed. 
	
	Params:
		_timeDelta - Maximum time change we are doing to counter attack timer [in seconds].
**/

private _timeDelta = _this select 0;
if (isNil "_timeDelta") exitWith {};
if !(_timeDelta isEqualType 0) exitWith {};
_mayor = if (_timeDelta >= 3600) then {true} else {false};
_timeDelta = _timeDelta - (((tierWar + difficultyCoef)-1)*300);

countCA = countCA + round (random _timeDelta);

if (_mayor and (countCA < 1200)) then {countCA = 1200};
publicVariable "countCA";