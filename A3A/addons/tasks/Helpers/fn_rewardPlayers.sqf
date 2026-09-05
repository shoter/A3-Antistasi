/*
    Splits mission reward between the faction fund, the commander and nearby players
    The commander sets the split in the HQ dialog (see A3A_fnc_setRewardShares):
        A3A_rewardTaxPercent        share paid into the faction fund, 0-50, default 0
        A3A_rewardCommanderPercent  share paid to the commander personally, 0-20, default 20
    Whatever is left is split equally between the rewarded players

Parameters:
    <NUMBER> Total reward
    <GROUP or BOOL> Group of player to reward, true for group of nearest player, false for all players
    <POSITION or OBJECT> Optional: Position to search from (applies for all modes)
    <NUMBER> Optional: Radius to search within (applies for all modes)

*/

params ["_totReward", "_group", ["_position", [0,0,0]], ["_radius", 1e7]];
if (_position isEqualType objNull) then { _position = getPosATL _position };

private _rewardPlayers = call {
    if (_group isEqualType grpNull) exitWith {
        units _group inAreaArray [_position, _radius, _radius] select { isPlayer _x };
    };
    private _allPlayers = call A3A_fnc_playableUnits;        // probably don't want to reward corpses
    if (!_group) exitWith {
        _allPlayers inAreaArray [_position, _radius, _radius];
    };
    // _group == true, use nearest player to determine group
    private _distances = _allPlayers apply { _x distance2d _position };
    private _nearPlayer = _allPlayers select (_distances find selectMin _distances);
    units _nearPlayer inAreaArray [_position, _radius, _radius];
};

// Faction tax comes off the top and goes straight into the war chest
// Reward points are worth 10 € each, see A3A_fnc_playerScoreAdd
private _taxPercent = 0 max (missionNamespace getVariable ["A3A_rewardTaxPercent", 0]) min 50;
private _taxReward = _totReward * _taxPercent / 100;
private _playerReward = _totReward - _taxReward;
if (_taxReward > 0) then {
    private _taxMoney = round (_taxReward * 10);
    [0, _taxMoney, true] spawn A3A_fnc_resourcesFIA;        // silent, the periodic income report shows the total instead
    A3A_rewardTaxCollected = (missionNamespace getVariable ["A3A_rewardTaxCollected", 0]) + _taxMoney;
};

// Now have list of players to be rewarded, add in the commander

if (!isNull theBoss) then {
    private _cutPercent = 0 max (missionNamespace getVariable ["A3A_rewardCommanderPercent", 20]) min 20;
    private _bossReward = _totReward * _cutPercent / 100;
    _playerReward = _playerReward - _bossReward;
    if (theBoss in _rewardPlayers) then { _bossReward = _bossReward + _playerReward / count _rewardPlayers };
    if (round _bossReward > 0) then { [round _bossReward, theBoss] call A3A_fnc_playerScoreAdd };
};

private _reward = round (_playerReward / (count _rewardPlayers max 1));
{ [_reward, _x] call A3A_fnc_playerScoreAdd } forEach (_rewardPlayers - [theBoss]);
