/*
Maintainer: Shoter
    Bribe money dialog of the buying intel mission, opened with the Load bribe money action on the money truck.
    Works like the Donate tab: pick an amount of your own money with the slider, the arrow buttons or the edit box
    and load it into the truck. Filled in by A3A_GUI_fnc_buyIntelDialog. All controls sit directly in the dialog
    (no controls group), in four rows that do not overlap: info text, amount, slider, buttons.
*/

class A3A_BuyIntelDialog
{
    idd = A3A_IDD_BUYINTELDIALOG;
    onLoad = "[""onLoad""] spawn A3A_GUI_fnc_buyIntelDialog";

    #undef DIALOG_X
    #undef DIALOG_Y
    #define DIALOG_X CENTER_X(120) // Global x pos of dialog
    #define DIALOG_Y CENTER_Y(52) // Global y pos of dialog

    class Controls
    {
        class Titlebar : A3A_TitlebarText
        {
            idc = -1;
            text = $STR_antistasi_dialogs_buy_intel_titlebar;
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
            h = 52 * GRID_H;
        };

        class InfoText : A3A_StructuredText
        {
            idc = A3A_IDC_BUYINTEL_INFOTEXT;
            text = "";
            x = DIALOG_X + 4 * GRID_W;
            y = DIALOG_Y + 3 * GRID_H;
            w = 112 * GRID_W;
            h = 18 * GRID_H;
        };

        class AmountLabel : A3A_Text
        {
            idc = -1;
            style = ST_LEFT;
            text = $STR_antistasi_dialogs_buy_intel_amount;
            sizeEx = GUI_TEXT_SIZE_LARGE;
            x = DIALOG_X + 4 * GRID_W;
            y = DIALOG_Y + 23 * GRID_H;
            w = 60 * GRID_W;
            h = 6 * GRID_H;
        };

        class MoneyEditBox : A3A_Edit
        {
            idc = A3A_IDC_BUYINTEL_EDITBOX;
            style = ST_RIGHT;
            text = "0";
            sizeEx = GUI_TEXT_SIZE_LARGE;
            onChar = "[""editBoxChanged""] spawn A3A_GUI_fnc_buyIntelDialog";
            x = DIALOG_X + 92 * GRID_W;
            y = DIALOG_Y + 23 * GRID_H;
            w = 20 * GRID_W;
            h = 6 * GRID_H;
        };

        class EuroLabel : A3A_Text
        {
            idc = -1;
            style = ST_RIGHT;
            text = "€";
            sizeEx = GUI_TEXT_SIZE_LARGE;
            x = DIALOG_X + 112 * GRID_W;
            y = DIALOG_Y + 23 * GRID_H;
            w = 4 * GRID_W;
            h = 6 * GRID_H;
        };

        class Sub1000Button : A3A_ShortcutButton
        {
            idc = -1;
            textureNoShortcut = A3A_ArrowEmpty_3L;
            onButtonClick = "[""add"", [-1000]] spawn A3A_GUI_fnc_buyIntelDialog";
            x = DIALOG_X + 4 * GRID_W;
            y = DIALOG_Y + 32 * GRID_H;
            w = 6 * GRID_W;
            h = 6 * GRID_H;

            class ShortcutPos
            {
                left = 0;
                top = 0;
                w = 6 * GRID_W;
                h = 6 * GRID_H;
            };
        };

        class Sub100Button : A3A_ShortcutButton
        {
            idc = -1;
            textureNoShortcut = A3A_ArrowEmpty_2L;
            onButtonClick = "[""add"", [-100]] spawn A3A_GUI_fnc_buyIntelDialog";
            x = DIALOG_X + 11 * GRID_W;
            y = DIALOG_Y + 32 * GRID_H;
            w = 6 * GRID_W;
            h = 6 * GRID_H;

            class ShortcutPos
            {
                left = 0;
                top = 0;
                w = 6 * GRID_W;
                h = 6 * GRID_H;
            };
        };

        class MoneySlider : A3A_Slider
        {
            idc = A3A_IDC_BUYINTEL_SLIDER;
            color[] = {1,1,1,1};
            arrowEmpty = A3A_ArrowEmpty_1L;
            arrowFull = A3A_ArrowFull_1L;
            onSliderPosChanged = "[""sliderChanged""] spawn A3A_GUI_fnc_buyIntelDialog";
            x = DIALOG_X + 18 * GRID_W;
            y = DIALOG_Y + 32 * GRID_H;
            w = 84 * GRID_W;
            h = 6 * GRID_H;
        };

        class Add100Button : A3A_ShortcutButton
        {
            idc = -1;
            textureNoShortcut = A3A_ArrowEmpty_2R;
            onButtonClick = "[""add"", [100]] spawn A3A_GUI_fnc_buyIntelDialog";
            x = DIALOG_X + 103 * GRID_W;
            y = DIALOG_Y + 32 * GRID_H;
            w = 6 * GRID_W;
            h = 6 * GRID_H;

            class ShortcutPos
            {
                left = 0;
                top = 0;
                w = 6 * GRID_W;
                h = 6 * GRID_H;
            };
        };

        class Add1000Button : A3A_ShortcutButton
        {
            idc = -1;
            textureNoShortcut = A3A_ArrowEmpty_3R;
            onButtonClick = "[""add"", [1000]] spawn A3A_GUI_fnc_buyIntelDialog";
            x = DIALOG_X + 110 * GRID_W;
            y = DIALOG_Y + 32 * GRID_H;
            w = 6 * GRID_W;
            h = 6 * GRID_H;

            class ShortcutPos
            {
                left = 0;
                top = 0;
                w = 6 * GRID_W;
                h = 6 * GRID_H;
            };
        };

        class CancelButton : A3A_Button
        {
            idc = -1;
            text = $STR_antistasi_dialogs_buy_intel_cancel;
            onButtonClick = "closeDialog 0";
            x = DIALOG_X + 4 * GRID_W;
            y = DIALOG_Y + 43 * GRID_H;
            w = 54 * GRID_W;
            h = 6 * GRID_H;
        };

        class LoadButton : A3A_Button
        {
            idc = A3A_IDC_BUYINTEL_LOADBUTTON;
            text = $STR_antistasi_dialogs_buy_intel_load;
            onButtonClick = "[""load""] call A3A_GUI_fnc_buyIntelDialog";
            x = DIALOG_X + 62 * GRID_W;
            y = DIALOG_Y + 43 * GRID_H;
            w = 54 * GRID_W;
            h = 6 * GRID_H;
        };
    };
};
