_resourcesFIA = server getVariable "resourcesFIA";
if (_resourcesFIA < 100) exitWith {hint "FIA has not enough resources to grab"};
[100] call A3A_fnc_resourcesPlayer;
server setvariable ["resourcesFIA",_resourcesFIA - 100, true];
[] remoteExec ["A3A_fnc_statistics",theBoss];

hint format ["You grabbed 100 € from the %1 Money Pool.",nameTeamPlayer];