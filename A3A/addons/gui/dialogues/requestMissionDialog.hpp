/*
Maintainer: Shoter
    Mission board, opened from Petros' mission action or the commander's Mission board button.
    A table of the missions currently on offer (Mission | Type | Location | Reward), a category filter,
    the countdown to the next batch of missions, details of the selected mission and a button to take it.
    Filled by A3A_GUI_fnc_requestMissionDialog.
*/

class A3A_RequestMissionDialog
{
    idd = A3A_IDD_REQUESTMISSIONDIALOG;
    onLoad = "[""onLoad""] spawn A3A_GUI_fnc_requestMissionDialog";

    #undef DIALOG_X
    #undef DIALOG_Y
    #define DIALOG_X CENTER_X(190) // Global x pos of dialog
    #define DIALOG_Y CENTER_Y(110) // Global y pos of dialog

    class ControlsBackground
    {
        class TitleBarBackground : A3A_Background
        {
            moving = true;
            colorBackground[] = A3A_COLOR_TITLEBAR_BACKGROUND;
            x = DIALOG_X;
            y = DIALOG_Y - 5 * GRID_H;
            w = 190 * GRID_W;
            h = 5 * GRID_H;
        };

        class Background : A3A_Background
        {
            x = DIALOG_X;
            y = DIALOG_Y;
            w = 190 * GRID_W;
            h = 110 * GRID_H;
        };
    };

    class Controls
    {
        class TitlebarText : A3A_TitlebarText
        {
            idc = -1;
            text = $STR_antistasi_dialogs_mission_board_titlebar;
            x = DIALOG_X;
            y = DIALOG_Y - 5 * GRID_H;
            w = 180 * GRID_W;
            h = 5 * GRID_H;
        };

        class CategoryFilter : A3A_ComboBox_Small
        {
            idc = A3A_IDC_MISSIONBOARD_FILTER;
            onLBSelChanged = "[""fillList""] call A3A_GUI_fnc_requestMissionDialog";
            x = DIALOG_X + 4 * GRID_W;
            y = DIALOG_Y + 3 * GRID_H;
            w = 50 * GRID_W;
            h = 4 * GRID_H;
        };

        class NextUpdateText : A3A_Text_Small
        {
            idc = A3A_IDC_MISSIONBOARD_NEXTUPDATE;
            style = ST_RIGHT;
            text = "";
            x = DIALOG_X + 60 * GRID_W;
            y = DIALOG_Y + 3 * GRID_H;
            w = 126 * GRID_W;
            h = 4 * GRID_H;
        };

        // Column headers. X positions follow the column fractions of MissionList below (4 + fraction * 182).
        class MissionHeader : A3A_Text_Small
        {
            idc = -1;
            text = $STR_antistasi_dialogs_mission_board_col_mission;
            colorText[] = A3A_COLOR_TEXT_DARKER;
            x = DIALOG_X + 4 * GRID_W;
            y = DIALOG_Y + 9 * GRID_H;
            w = 54 * GRID_W;
            h = 4 * GRID_H;
        };

        class TypeHeader : MissionHeader
        {
            text = $STR_antistasi_dialogs_mission_board_col_type;
            x = DIALOG_X + 58.6 * GRID_W;
            w = 27 * GRID_W;
        };

        class LocationHeader : MissionHeader
        {
            text = $STR_antistasi_dialogs_mission_board_col_location;
            x = DIALOG_X + 85.9 * GRID_W;
            w = 36 * GRID_W;
        };

        class RewardHeader : MissionHeader
        {
            text = $STR_antistasi_dialogs_mission_board_col_reward;
            x = DIALOG_X + 122.3 * GRID_W;
            w = 63 * GRID_W;
        };

        class MissionListBackground : A3A_Background
        {
            idc = -1;
            colorBackground[] = A3A_COLOR_BACKGROUND;
            x = DIALOG_X + 4 * GRID_W;
            y = DIALOG_Y + 13 * GRID_H;
            w = 182 * GRID_W;
            h = 64 * GRID_H;
        };

        class MissionList : A3A_ListNBox
        {
            idc = A3A_IDC_MISSIONBOARD_LIST;
            onLBSelChanged = "[""selectionChanged""] call A3A_GUI_fnc_requestMissionDialog";
            onLBDblClick = "[""accept""] call A3A_GUI_fnc_requestMissionDialog";
            x = DIALOG_X + 4 * GRID_W;
            y = DIALOG_Y + 13 * GRID_H;
            w = 182 * GRID_W;
            h = 64 * GRID_H;

            sizeEx = GUI_TEXT_SIZE_SMALL;
            rowHeight = 4 * GRID_H;
            columns[] = {0, 0.3, 0.45, 0.65}; // Mission, Type, Location, Reward
        };

        class DetailsText : A3A_StructuredText
        {
            idc = A3A_IDC_MISSIONBOARD_DETAILS;
            text = "";
            x = DIALOG_X + 4 * GRID_W;
            y = DIALOG_Y + 80 * GRID_H;
            w = 140 * GRID_W;
            h = 27 * GRID_H;
        };

        class AcceptButton : A3A_Button
        {
            idc = A3A_IDC_MISSIONBOARD_ACCEPT;
            text = $STR_antistasi_dialogs_mission_board_accept;
            onButtonClick = "[""accept""] call A3A_GUI_fnc_requestMissionDialog";
            x = DIALOG_X + 148 * GRID_W;
            y = DIALOG_Y + 97 * GRID_H;
            w = 38 * GRID_W;
            h = 10 * GRID_H;
        };

        class CloseButton : A3A_CloseButton
        {
            idc = -1;
            x = DIALOG_X + 190 * GRID_W - 5 * GRID_W;
            y = DIALOG_Y - 5 * GRID_H;
        };
    };
};

// Restore the default dialog position for the dialogs included after this one
#undef DIALOG_X
#undef DIALOG_Y
#define DIALOG_X CENTER_X(DIALOG_W) // Global x pos of dialog
#define DIALOG_Y CENTER_Y(DIALOG_H) // Global y pos of dialog
