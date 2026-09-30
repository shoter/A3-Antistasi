/*
Maintainer: Shoter
    Reward a mission board entry pays on full success, shown to players before they take the mission.
    The numbers mirror the payouts in the mission files. Change both together, or the board lies.

Arguments:
    <STRING> Task class name from configFile >> "A3A" >> "Tasks"
    <BOOL> Hard variant, rolled by the board and passed to the mission [DEFAULT = false]
    <ANY> Task-specific extra: convoy type for "convoy", reward money for "RES_Defector" [DEFAULT = ""]

Return Value:
    <ARRAY> [faction money, player reward points (10 € each, see A3A_tasks_fnc_rewardPlayers), HR,
             stringtable key of the unit the reward is paid per ("" when paid once), stringtable key of an extra reward ("" when none)]

Scope: Any
Environment: Any
Public: No

Example:
    ["AS_Official", true] call A3A_tasks_fnc_boardReward;      // [600, 60, 0, "", ""]
*/
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

params ["_task", ["_hard", false], ["_extra", ""]];

private _bonus = [1, 2] select _hard;

switch (_task) do
{
    case "AS_Collaborator";
    case "AS_Official";
    case "AS_Traitor";
    case "DES_Heli";
    case "LOG_Salvage": { [300 * _bonus, 30 * _bonus, 0, "", ""] };
    case "AS_specOP": { [[200, 300] select _hard, [20, 30] select _hard, 0, "", ""] };
    case "CON_Outpost": { [200 * _bonus, 20 * _bonus, 0, "", ""] };
    case "DES_Antenna": { [0, 20 * _bonus, 0, "", ""] };
    case "LOG_Bank": { [5000 * _bonus, 20 * _bonus, 0, "", ""] };
    case "LOG_Gunshop": { [0, 0, 0, "", "STR_A3A_Tasks_board_note_gunshop"] };
    case "LOG_Weapons": { [200, 20, 0, "", "STR_A3A_Tasks_board_note_weapons"] };
    case "LOG_LostAmmo": { [300, 30, 0, "", "STR_A3A_Tasks_board_note_ammo"] };
    case "RES_Prisoners": { [100 * _bonus, 4 * _bonus, 2, "STR_A3A_Tasks_board_per_pow", ""] };
    case "RES_Refugees": { [50 * _bonus, 4 * _bonus, 1, "STR_A3A_Tasks_board_per_refugee", ""] };
    case "DES_Camp": { [0, 0, 0, "", "STR_A3A_Tasks_board_note_camp"] };           // paid to each player directly
    case "LOG_Hideout": { [0, 0, 0, "", "STR_A3A_Tasks_board_note_hideout"] };     // paid to each player directly
    case "RES_Defector": { [_extra, 30, 0, "", "STR_A3A_Tasks_board_note_intel"] };
    case "SUP_Elderly": { [0, 0, 0, "", "STR_A3A_Tasks_board_note_support"] };        // town support only
    case "SUP_PoliceStation";
    case "SUP_Supplies": { [200, 20, 0, "", ""] };
    case "convoy":
    {
        // Convoys use a 1.5 bonus, and rewardPlayers gets three times the score adjustment
        private _convoyBonus = [1, 1.5] select _hard;
        switch (_extra) do
        {
            case "Money": { [5000 * _convoyBonus, 30 * _convoyBonus, 0, "", ""] };
            case "Prisoners": { [300 * _convoyBonus, 3 * _convoyBonus, 1, "STR_A3A_Tasks_board_per_pow", ""] };
            case "Ammunition": { [0, 30, 0, "", "STR_A3A_Tasks_board_note_ammo"] };
            default { [0, 30 * _convoyBonus, 0, "", ""] };         // Armor, Reinforcements, Supplies
        };
    };
    default { [0, 0, 0, "", ""] };
};
