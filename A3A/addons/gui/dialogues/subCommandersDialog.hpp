/*
Maintainer: Shoter
    Sub-commanders dialog, opened with the Sub-commanders button on the Commander tab of the Battle Command menu.
    Lists the players on the server and the sub-commanders who are offline, one line per player with a button
    to designate them or to take the role away. The rows are created by A3A_GUI_fnc_subCommandersDialog.
*/

class A3A_SubCommandersDialog
{
    idd = A3A_IDD_SUBCOMMANDERSDIALOG;
    onLoad = "[""onLoad""] spawn A3A_GUI_fnc_subCommandersDialog";

    #undef DIALOG_X
    #undef DIALOG_Y
    #define DIALOG_X CENTER_X(140) // Global x pos of dialog
    #define DIALOG_Y CENTER_Y(92) // Global y pos of dialog

    class Controls
    {
        class Titlebar : A3A_TitlebarText
        {
            idc = -1;
            text = $STR_antistasi_dialogs_subcommanders_titlebar;
            colorBackground[] = A3A_COLOR_TITLEBAR_BACKGROUND;
            x = DIALOG_X;
            y = DIALOG_Y - 5 * GRID_H;
            w = 140 * GRID_W;
            h = 5 * GRID_H;
        };

        class Background : A3A_Background
        {
            idc = -1;
            x = DIALOG_X;
            y = DIALOG_Y;
            w = 140 * GRID_W;
            h = 92 * GRID_H;
        };

        class InfoText : A3A_StructuredText
        {
            idc = -1;
            text = $STR_antistasi_dialogs_subcommanders_info;
            size = GUI_TEXT_SIZE_SMALL;
            x = DIALOG_X + 4 * GRID_W;
            y = DIALOG_Y + 2 * GRID_H;
            w = 132 * GRID_W;
            h = 14 * GRID_H;
        };

        // Column captions, X positions follow the row layout created in fn_subCommandersDialog "update" (list x + column offset)
        class NameHeader : A3A_Text
        {
            idc = -1;
            text = $STR_antistasi_dialogs_main_towns_name_label;
            sizeEx = GUI_TEXT_SIZE_SMALL;
            colorText[] = A3A_COLOR_TEXT_DARKER;
            x = DIALOG_X + 5 * GRID_W;
            y = DIALOG_Y + 17 * GRID_H;
            w = 54 * GRID_W;
            h = 4 * GRID_H;
        };

        class RoleHeader : NameHeader
        {
            text = $STR_antistasi_dialogs_subcommanders_role_label;
            x = DIALOG_X + 60 * GRID_W;
            w = 34 * GRID_W;
        };

        class SquadsHeader : NameHeader
        {
            text = $STR_antistasi_dialogs_subcommanders_squads_label;
            tooltip = $STR_antistasi_dialogs_subcommanders_squads_tooltip;
            x = DIALOG_X + 95 * GRID_W;
            w = 14 * GRID_W;
        };

        class PlayerListBackground : A3A_Background
        {
            idc = -1;
            x = DIALOG_X + 4 * GRID_W;
            y = DIALOG_Y + 21 * GRID_H;
            w = 132 * GRID_W;
            h = 64 * GRID_H;
        };

        // Rows are created at runtime, one line of controls per player with a Designate or Remove button
        class PlayerList : A3A_ControlsGroupNoHScrollbars
        {
            idc = A3A_IDC_SUBCOMMANDERS_LIST;
            x = DIALOG_X + 4 * GRID_W;
            y = DIALOG_Y + 21 * GRID_H;
            w = 132 * GRID_W;
            h = 64 * GRID_H;
        };

        class StatusText : A3A_Text
        {
            idc = A3A_IDC_SUBCOMMANDERS_STATUSTEXT;
            text = "";
            sizeEx = GUI_TEXT_SIZE_SMALL;
            x = DIALOG_X + 4 * GRID_W;
            y = DIALOG_Y + 86 * GRID_H;
            w = 132 * GRID_W;
            h = 4 * GRID_H;
        };

        class CloseButton : A3A_CloseButton
        {
            idc = -1;
            x = DIALOG_X + 140 * GRID_W - 5 * GRID_W;
            y = DIALOG_Y - 5 * GRID_H;
        };
    };
};
