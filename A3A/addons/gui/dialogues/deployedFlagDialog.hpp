/*
Maintainer: Shoter
    Confirmation dialog for teleporting to the commander rally flag, opened from the HQ flag.
    Shows distance, enemy presence at the flag, travel time, cost and the squad AI coming along,
    filled in by A3A_GUI_fnc_deployedFlagDialog. The Teleport button is disabled when the player
    cannot afford the trip or cannot travel at all.
*/

class A3A_DeployedFlagDialog
{
    idd = A3A_IDD_DEPLOYEDFLAGDIALOG;
    onLoad = "[""onLoad""] spawn A3A_GUI_fnc_deployedFlagDialog";

    #define DIALOG_X CENTER_X(110) // Global x pos of dialog
    #define DIALOG_Y CENTER_Y(66) // Global y pos of dialog

    class Controls
    {
        class Titlebar : A3A_TitlebarText
        {
            idc = -1;
            text = $STR_antistasi_dialogs_deployed_flag_titlebar;
            colorBackground[] = A3A_COLOR_TITLEBAR_BACKGROUND;
            x = DIALOG_X;
            y = DIALOG_Y - 5 * GRID_H;
            w = 110 * GRID_W;
            h = 5 * GRID_H;
        };

        class Background : A3A_Background
        {
            idc = -1;
            x = DIALOG_X;
            y = DIALOG_Y;
            w = 110 * GRID_W;
            h = 66 * GRID_H;
        };

        class InfoText : A3A_StructuredText
        {
            idc = A3A_IDC_DEPLOYEDFLAG_INFOTEXT;
            text = "";
            x = DIALOG_X + 4 * GRID_W;
            y = DIALOG_Y + 3 * GRID_H;
            w = 102 * GRID_W;
            h = 51 * GRID_H;
        };

        class CancelButton : A3A_Button
        {
            idc = A3A_IDC_DEPLOYEDFLAG_CANCELBUTTON;
            text = $STR_antistasi_dialogs_deployed_flag_cancel;
            onButtonClick = "closeDialog 0";
            x = DIALOG_X + 4 * GRID_W;
            y = DIALOG_Y + 57 * GRID_H;
            w = 49 * GRID_W;
            h = 6 * GRID_H;
        };

        class AcceptButton : A3A_Button
        {
            idc = A3A_IDC_DEPLOYEDFLAG_ACCEPTBUTTON;
            text = $STR_antistasi_dialogs_deployed_flag_accept;
            onButtonClick = "[""accept""] call A3A_GUI_fnc_deployedFlagDialog";
            x = DIALOG_X + 57 * GRID_W;
            y = DIALOG_Y + 57 * GRID_H;
            w = 49 * GRID_W;
            h = 6 * GRID_H;
        };
    };
};
