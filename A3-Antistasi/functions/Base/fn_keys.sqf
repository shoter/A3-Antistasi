_handled = false;
if (player getVariable ["INCAPACITATED",false]) exitWith {_handled};
if (player getVariable ["owner",player] != player) exitWith {_handled};
_key = _this select 1;

//Czarny
_defaultKey = "battleOptionsMenuKey" call BIS_fnc_getParamValue;

if ((_defaultKey == 0 && _key == 21) || (_defaultKey == 1 && _key == 22)) then
	{
	if (isNil"garageVeh") then
		{
		if (_this select 2) then
			{
			if (player == theBoss) then
				{
				[] spawn A3A_fnc_artySupport;
				};
			}
		else
			{
			closedialog 0;
			_nul = createDialog "radio_comm";
			};
		};
	}
else
	{
	if (_key == 207) then
		{
		if (!hasACEhearing) then
			{
			if (soundVolume <= 0.5) then
				{
				0.5 fadeSound 1;
				hintSilent "You've taken out your ear plugs.";
				}
			else
				{
				0.5 fadeSound 0.1;
				hintSilent "You've inserted your ear plugs.";
				};
			};
		};
	};
_handled