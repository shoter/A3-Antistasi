/*
Maintainer: Shoter
    Squad composer, opened with the Squad Composer button on the Commander tab of the Battle Command menu.
    Command staff choose the soldiers of custom squads 1 and 2 of the Recruit Squad dialog and their abbreviation in the
    high command bar. One line per unit type with buttons to change the count; the lines are created by
    A3A_GUI_fnc_squadComposerDialog. The squad leader line has no buttons, every custom squad has exactly one.
*/

class A3A_SquadComposerDialog
{
    idd = A3A_IDD_SQUADCOMPOSERDIALOG;
    onLoad = "[""onLoad""] spawn A3A_GUI_fnc_squadComposerDialog";

    #undef DIALOG_X
    #undef DIALOG_Y
    #define DIALOG_X CENTER_X(120) // Global x pos of dialog
    #define DIALOG_Y CENTER_Y(100) // Global y pos of dialog

    class Controls
    {
        class Titlebar : A3A_TitlebarText
        {
            idc = -1;
            text = $STR_antistasi_dialogs_squad_composer_titlebar;
            colorBackground[] = A3A_COLOR_TITLEBAR_BACKGROUND;
            x = DIALOG_X;
            y = DIALOG_Y - 5 * GRID_H;
            w = 120 * GRID_W;
            h = 5 * GRID_H;
        };

        class Background : A3A_Background
        {
            idc = -1;
            x = DIALOG_X;
            y = DIALOG_Y;
            w = 120 * GRID_W;
            h = 100 * GRID_H;
        };

        // Squad picker, the button of the squad being edited is disabled
        class Custom1Button : A3A_Button
        {
            idc = A3A_IDC_SQUADCOMPOSER_CUSTOM1BUTTON;
            text = $STR_antistasi_dialogs_squad_composer_custom1;
            onButtonClick = "[""select"", [0]] call A3A_GUI_fnc_squadComposerDialog";
            x = DIALOG_X + 4 * GRID_W;
            y = DIALOG_Y + 2 * GRID_H;
            w = 55 * GRID_W;
            h = 7 * GRID_H;
        };

        class Custom2Button : Custom1Button
        {
            idc = A3A_IDC_SQUADCOMPOSER_CUSTOM2BUTTON;
            text = $STR_antistasi_dialogs_squad_composer_custom2;
            onButtonClick = "[""select"", [1]] call A3A_GUI_fnc_squadComposerDialog";
            x = DIALOG_X + 61 * GRID_W;
        };

        class InfoText : A3A_StructuredText
        {
            idc = -1;
            text = $STR_antistasi_dialogs_squad_composer_info;
            size = GUI_TEXT_SIZE_SMALL;
            x = DIALOG_X + 4 * GRID_W;
            y = DIALOG_Y + 10 * GRID_H;
            w = 112 * GRID_W;
            h = 8 * GRID_H;
        };

        class AbbreviationLabel : A3A_Text
        {
            idc = -1;
            text = $STR_antistasi_dialogs_squad_composer_abbreviation_label;
            tooltip = $STR_antistasi_dialogs_squad_composer_abbreviation_tooltip;
            x = DIALOG_X + 4 * GRID_W;
            y = DIALOG_Y + 19 * GRID_H;
            w = 40 * GRID_W;
            h = 5 * GRID_H;
        };

        class AbbreviationEdit : A3A_Edit
        {
            idc = A3A_IDC_SQUADCOMPOSER_ABBREDIT;
            tooltip = $STR_antistasi_dialogs_squad_composer_abbreviation_tooltip;
            maxChars = 5;
            onKeyUp = "[""abbreviationChanged""] call A3A_GUI_fnc_squadComposerDialog; false";
            x = DIALOG_X + 44 * GRID_W;
            y = DIALOG_Y + 19 * GRID_H;
            w = 16 * GRID_W;
            h = 5 * GRID_H;
        };

        class AbbreviationPreview : A3A_Text
        {
            idc = A3A_IDC_SQUADCOMPOSER_ABBRPREVIEW;
            text = "";
            sizeEx = GUI_TEXT_SIZE_SMALL;
            colorText[] = A3A_COLOR_TEXT_DARKER;
            x = DIALOG_X + 62 * GRID_W;
            y = DIALOG_Y + 19 * GRID_H;
            w = 54 * GRID_W;
            h = 5 * GRID_H;
        };

        // Column captions, X positions follow the row layout created in fn_squadComposerDialog "onLoad" (list x + column offset)
        class SoldierHeader : A3A_Text
        {
            idc = -1;
            text = $STR_antistasi_dialogs_squad_composer_soldier_label;
            sizeEx = GUI_TEXT_SIZE_SMALL;
            colorText[] = A3A_COLOR_TEXT_DARKER;
            x = DIALOG_X + 5 * GRID_W;
            y = DIALOG_Y + 26 * GRID_H;
            w = 44 * GRID_W;
            h = 4 * GRID_H;
        };

        class PriceHeader : SoldierHeader
        {
            text = $STR_antistasi_dialogs_squad_composer_price_label;
            style = ST_RIGHT;
            x = DIALOG_X + 50 * GRID_W;
            w = 16 * GRID_W;
        };

        class CountHeader : SoldierHeader
        {
            text = $STR_antistasi_dialogs_squad_composer_count_label;
            style = ST_RIGHT;
            x = DIALOG_X + 83 * GRID_W;
            w = 9 * GRID_W;
        };

        class UnitListBackground : A3A_Background
        {
            idc = -1;
            x = DIALOG_X + 4 * GRID_W;
            y = DIALOG_Y + 30 * GRID_H;
            w = 112 * GRID_W;
            h = 46 * GRID_H;
        };

        // Rows are created at runtime, the squad leader and the 8 other garrison unit types, 5 grid units each
        class UnitList : A3A_ControlsGroupNoScrollbars
        {
            idc = A3A_IDC_SQUADCOMPOSER_LIST;
            x = DIALOG_X + 4 * GRID_W;
            y = DIALOG_Y + 30 * GRID_H;
            w = 112 * GRID_W;
            h = 46 * GRID_H;
        };

        class SizeText : A3A_Text
        {
            idc = A3A_IDC_SQUADCOMPOSER_SIZETEXT;
            text = "";
            x = DIALOG_X + 4 * GRID_W;
            y = DIALOG_Y + 78 * GRID_H;
            w = 40 * GRID_W;
            h = 5 * GRID_H;
        };

        class CostText : A3A_TextRight
        {
            idc = A3A_IDC_SQUADCOMPOSER_COSTTEXT;
            text = "";
            x = DIALOG_X + 44 * GRID_W;
            y = DIALOG_Y + 78 * GRID_H;
            w = 72 * GRID_W;
            h = 5 * GRID_H;
        };

        class VehicleText : A3A_Text
        {
            idc = A3A_IDC_SQUADCOMPOSER_VEHICLETEXT;
            text = "";
            sizeEx = GUI_TEXT_SIZE_SMALL;
            colorText[] = A3A_COLOR_TEXT_DARKER;
            x = DIALOG_X + 4 * GRID_W;
            y = DIALOG_Y + 83 * GRID_H;
            w = 112 * GRID_W;
            h = 5 * GRID_H;
        };

        class StatusText : A3A_Text
        {
            idc = A3A_IDC_SQUADCOMPOSER_STATUSTEXT;
            text = "";
            sizeEx = GUI_TEXT_SIZE_SMALL;
            x = DIALOG_X + 4 * GRID_W;
            y = DIALOG_Y + 92 * GRID_H;
            w = 60 * GRID_W;
            h = 5 * GRID_H;
        };

        class RevertButton : A3A_Button
        {
            idc = A3A_IDC_SQUADCOMPOSER_REVERTBUTTON;
            text = $STR_antistasi_dialogs_squad_composer_revert_button;
            tooltip = $STR_antistasi_dialogs_squad_composer_revert_tooltip;
            onButtonClick = "[""revert""] call A3A_GUI_fnc_squadComposerDialog";
            x = DIALOG_X + 66 * GRID_W;
            y = DIALOG_Y + 91 * GRID_H;
            w = 24 * GRID_W;
            h = 6 * GRID_H;
        };

        class SaveButton : RevertButton
        {
            idc = A3A_IDC_SQUADCOMPOSER_SAVEBUTTON;
            text = $STR_antistasi_dialogs_squad_composer_save_button;
            tooltip = $STR_antistasi_dialogs_squad_composer_save_tooltip;
            onButtonClick = "[""save""] call A3A_GUI_fnc_squadComposerDialog";
            x = DIALOG_X + 92 * GRID_W;
        };

        class CloseButton : A3A_CloseButton
        {
            idc = -1;
            x = DIALOG_X + 120 * GRID_W - 5 * GRID_W;
            y = DIALOG_Y - 5 * GRID_H;
        };
    };
};
