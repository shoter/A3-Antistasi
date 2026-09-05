class A3A_JunkyardDialog : A3A_DefaultDialog
{
    idd = A3A_IDD_JUNKYARDDIALOG;
    onLoad = "[""onLoad""] spawn A3A_GUI_fnc_junkyardDialog";

    class Controls
    {
        class TitlebarText : A3A_TitlebarText
        {
            idc = -1;
            text = $STR_antistasi_dialogs_junkyard_titlebar;
            x = DIALOG_X;
            y = DIALOG_Y - 5 * GRID_H;
            w = DIALOG_W * GRID_W;
            h = 5 * GRID_H;
        };

        class InfoText : A3A_InfoTextLeft
        {
            idc = A3A_IDC_JUNKYARDINFOTEXT;
            text = "";
            x = DIALOG_X + 2 * GRID_W;
            y = DIALOG_Y + 1 * GRID_H;
            w = 100 * GRID_W;
            h = 4 * GRID_H;
        };

        // Commander only, hidden for everyone else by the onLoad function
        class FactionFundsCheckbox : A3A_CheckBox
        {
            idc = A3A_IDC_JUNKYARDFACTIONFUNDS;
            checked = 1;
            show = false;
            x = DIALOG_X + DIALOG_W * GRID_W - 46 * GRID_W;
            y = DIALOG_Y + 1 * GRID_H;
            w = 4 * GRID_W;
            h = 4 * GRID_H;
        };

        class FactionFundsText : A3A_InfoTextLeft
        {
            idc = A3A_IDC_JUNKYARDFACTIONFUNDSTEXT;
            text = $STR_antistasi_dialogs_junkyard_faction_funds;
            show = false;
            x = DIALOG_X + DIALOG_W * GRID_W - 41 * GRID_W;
            y = DIALOG_Y + 1 * GRID_H;
            w = 40 * GRID_W;
            h = 4 * GRID_H;
        };

        // Debug: admins only, hidden for everyone else by the onLoad function
        class RefreshButton : A3A_Button
        {
            idc = A3A_IDC_JUNKYARDREFRESHBUTTON;
            text = $STR_antistasi_dialogs_junkyard_refresh;
            show = false;
            onButtonClick = "closeDialog 0; [player] remoteExecCall ['A3A_fnc_junkyardAdminRefresh', 2];";
            x = DIALOG_X + DIALOG_W * GRID_W - 82 * GRID_W;
            y = DIALOG_Y + 0.5 * GRID_H;
            w = 32 * GRID_W;
            h = 5 * GRID_H;
        };

        class VehiclesControlsGroup : A3A_ControlsGroupNoHScrollbars
        {
            idc = A3A_IDC_JUNKYARDVEHICLESGROUP;
            x = DIALOG_X;
            y = DIALOG_Y + 6 * GRID_H;
            w = PX_W(DIALOG_W);
            h = PX_H(DIALOG_H) - 6 * GRID_H;
        };

        class CloseButton : A3A_CloseButton
        {
            idc = -1;
            x = DIALOG_X + DIALOG_W * GRID_W - 5 * GRID_W;
            y = DIALOG_Y - 5 * GRID_H;
        };
    };

    // Used for preview renders. Has to be defined inline. Class inheritance incompatible. ctrlCreate incompatible.
    class Objects
    {
        class VehiclePreview
        {
            idc = A3A_IDC_JUNKYARDOBJECTRENDER;

            type = 82;
            model = "\A3\Structures_F\Items\Food\Can_V3_F.p3d";
            scale = 0.00001;  // Hide unless there is a mouse hover. This is overwritten by proper ctrlShow command on initialisation.

            direction[] = {0, -0.35, -0.65};
            up[] = {0, 0.65, -0.35};

            x = 0.5;
            y = 0.5;
            z = 0.2;

            xBack = 0.5;
            yBack = 0.5;
            zBack = 1.2;

            inBack = 1;
            enableZoom = 1;
            zoomDuration = 0.001;
        };
    };
};
