_playersIncome = _this select 0;
_playersCurrentMoney = player getVariable "moneyX";

_tresholds = [[1000, 0], [500, 0.1], [250, 0.15], [0, 0.2]];		// [moneyLimit, percentOfIncome], preserve descending order of playersMoney

for [{_i = 0}, {_i < count _tresholds}, {_i = _i + 1}] do 
{	
	_treshold = _tresholds select _i;
	_limit = _treshold select 0;

	if(_playersCurrentMoney > _limit) then			// check if players amount of money is higher than possible income, if yes apply formula
	{
		exitWith 
		{
			_playersIncome = round (_playersIncome * (_treshold select 1));
			if(_playersIncome > _limit) then			// income can't be higher than treshold, its function is small and convenient support than main source of income
			{
				_playersIncome = _limit ;
			};
		};
	};
};

[_playersIncome] call A3A_fnc_resoucesPlayer;

_playersIncome