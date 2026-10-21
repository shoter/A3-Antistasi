/*
Maintainer: Shoter
    Timed action progress bar at the bottom centre of the screen: a caption above a bar that fills from the left.
    Driven by A3A_GUI_fnc_progressBar, shown with cutRsc on its own layer.
*/

#define PROGRESSBAR_W 80
#define PROGRESSBAR_X (safeZoneX + safeZoneW / 2 - PROGRESSBAR_W / 2 * GRID_W)
#define PROGRESSBAR_Y (safeZoneY + safeZoneH - 30 * GRID_H)

class A3A_ProgressBar {
    idd = A3A_IDD_PROGRESSBAR;
    fadeIn = 0;
    fadeOut = 0;
    duration = 999999;
    enableSimulation = 1;
    onLoad = "uiNamespace setVariable ['A3A_progressBarDisplay', _this select 0]";

    class controls {
        class Background: A3A_Background {
            idc = -1;
            colorBackground[] = {0,0,0,0.6};
            x = PROGRESSBAR_X;
            y = PROGRESSBAR_Y;
            w = PROGRESSBAR_W * GRID_W;
            h = 9 * GRID_H;
        };

        class Caption: A3A_Text {
            idc = A3A_IDC_PROGRESSBARTEXT;
            style = ST_CENTER;
            text = "";
            x = PROGRESSBAR_X + 1 * GRID_W;
            y = PROGRESSBAR_Y + 0.5 * GRID_H;
            w = (PROGRESSBAR_W - 2) * GRID_W;
            h = 4 * GRID_H;
        };

        class Track: A3A_Background {
            idc = -1;
            colorBackground[] = {1,1,1,0.15};
            x = PROGRESSBAR_X + 1 * GRID_W;
            y = PROGRESSBAR_Y + 5.5 * GRID_H;
            w = (PROGRESSBAR_W - 2) * GRID_W;
            h = 2 * GRID_H;
        };

        // Width set by A3A_GUI_fnc_progressBar, from 0 to the width of Track. Same rectangle as Track on purpose, drawn above it.
        class Fill: A3A_Background {
            idc = A3A_IDC_PROGRESSBARFILL;
            colorBackground[] = {0.9,0.7,0.2,1};
            x = PROGRESSBAR_X + 1 * GRID_W;
            y = PROGRESSBAR_Y + 5.5 * GRID_H;
            w = 0;
            h = 2 * GRID_H;
        };
    };
};
