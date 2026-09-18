/*
Maintainer: Shoter
    Order dialog for a loot crate delivery, opened with the Loot crate button of the Battle Command menu.
    Shows who pays and what the pickup and the plane cost, filled in by A3A_GUI_fnc_lootDeliveryDialog.
    The Pickup and Plane buttons are disabled when that option is unavailable or unaffordable.
*/

class A3A_LootDeliveryDialog
{
    idd = A3A_IDD_LOOTDELIVERYDIALOG;
    onLoad = "[""onLoad""] spawn A3A_GUI_fnc_lootDeliveryDialog";

    #undef DIALOG_X
    #undef DIALOG_Y
    #define DIALOG_X CENTER_X(120) // Global x pos of dialog
    #define DIALOG_Y CENTER_Y(84) // Global y pos of dialog

    class Controls
    {
        class Titlebar : A3A_TitlebarText
        {
            idc = -1;
            text = $STR_antistasi_dialogs_loot_delivery_titlebar;
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
            h = 84 * GRID_H;
        };

        class InfoText : A3A_StructuredText
        {
            idc = A3A_IDC_LOOTDELIVERY_INFOTEXT;
            text = "";
            x = DIALOG_X + 4 * GRID_W;
            y = DIALOG_Y + 3 * GRID_H;
            w = 112 * GRID_W;
            h = 69 * GRID_H;
        };

        class CancelButton : A3A_Button
        {
            idc = A3A_IDC_LOOTDELIVERY_CANCELBUTTON;
            text = $STR_antistasi_dialogs_loot_delivery_cancel;
            onButtonClick = "closeDialog 0";
            x = DIALOG_X + 4 * GRID_W;
            y = DIALOG_Y + 75 * GRID_H;
            w = 34 * GRID_W;
            h = 6 * GRID_H;
        };

        class PickupButton : A3A_Button
        {
            idc = A3A_IDC_LOOTDELIVERY_PICKUPBUTTON;
            text = $STR_antistasi_dialogs_loot_delivery_pickup;
            onButtonClick = "[""order"", [""pickup""]] call A3A_GUI_fnc_lootDeliveryDialog";
            x = DIALOG_X + 43 * GRID_W;
            y = DIALOG_Y + 75 * GRID_H;
            w = 34 * GRID_W;
            h = 6 * GRID_H;
        };

        class PlaneButton : A3A_Button
        {
            idc = A3A_IDC_LOOTDELIVERY_PLANEBUTTON;
            text = $STR_antistasi_dialogs_loot_delivery_plane;
            onButtonClick = "[""order"", [""plane""]] call A3A_GUI_fnc_lootDeliveryDialog";
            x = DIALOG_X + 82 * GRID_W;
            y = DIALOG_Y + 75 * GRID_H;
            w = 34 * GRID_W;
            h = 6 * GRID_H;
        };
    };
};
