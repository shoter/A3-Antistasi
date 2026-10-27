/*
Maintainer: Caleb Serafin, Killerswin2, Hakon
	Creates the controls for the dialog. Picture and Button are created. Data Saved to buttons.

Arguments:
	<string> string for initilizer

Return Value:
	NONE

Scope: Client
Environment: scheduled
Public: No
Example:
	["onLoad"] spawn A3A_GUI_fnc_teamLeaderRTSPlacerDialog

License: APL-ND
	As of 1st July 2024 Ellis Nielsen, the owner of the code, has transfered the ownership to Calep Serafin.

*/




#include "..\..\dialogues\ids.inc"
#include "..\..\dialogues\defines.hpp"
#include "..\..\dialogues\textures.inc"
#include "..\..\script_component.hpp"
#include "\x\A3A\addons\core\functions\Builder\placerDefines.hpp"
#define BOTTOM safeZoneH + safeZoneY
FIX_LINE_NUMBERS()

params[["_mode","onLoad"], ["_params",[]]];

switch (_mode) do
{
	case ("updateMoney"):
	{
		private _display = findDisplay A3A_IDD_TEAMLEADERDIALOG;
		private _moneyCtrl = _display displayCtrl A3A_IDC_TEAMLEADERBUILDERMONEY;

		_moneyCtrl ctrlSetText format ["%1 €", A3A_building_EHDB # AVAILABLE_MONEY];
	};
	case ("filter"):
	{
		// Lay out the tiles whose name or classname contains the filter text, hide the rest
		private _display = findDisplay A3A_IDD_TEAMLEADERDIALOG;
		private _tiles = _display getVariable "A3A_buildTiles";
		if (isNil "_tiles") exitWith {};			// onLoad still creating the tiles, it filters when done

		private _filter = toLower ctrlText (_display displayCtrl A3A_IDC_TEAMLEADERBUILDERFILTER);
		private _layout = _display getVariable "A3A_buildTileLayout";
		_layout params ["_itemsPerRow", "_itemWidth"];

		private _shown = 0;
		{
			_x params ["_itemControlsGroup", "_searchText"];
			if (_filter != "" && { _searchText find _filter == -1 }) then {
				_itemControlsGroup ctrlSetPosition [0, 0];			// parked at the origin so it doesn't stretch the scroll area
				_itemControlsGroup ctrlCommit 0;
				_itemControlsGroup ctrlShow false;
				continue;
			};
			private _itemXpos = (4 + (4 + _itemWidth) * (_shown % _itemsPerRow)) * GRID_W;
			private _itemYpos = (floor (_shown / _itemsPerRow)) * (34 * GRID_H);
			_itemControlsGroup ctrlSetPosition [_itemXpos, _itemYpos];
			_itemControlsGroup ctrlCommit 0;
			_itemControlsGroup ctrlShow true;
			_shown = _shown + 1;
		} forEach _tiles;

		// Back to the top, the old scroll position may be past the end of the shorter list
		private _buildControlsGroup = (_display displayCtrl A3A_IDC_TEAMLEADERBUILDERMAIN) controlsGroupCtrl A3A_IDC_TEAMLEADERBUILDINGGROUP;
		_buildControlsGroup ctrlSetScrollValues [0, -1];
	};
	case ("releaseFilterFocus"):
	{
		// Move keyboard focus off the filter so the placer keys (Space, E, R, C...) work again
		private _display = findDisplay A3A_IDD_TEAMLEADERDIALOG;
		private _lastButton = _display getVariable ["A3A_lastBuildButton", controlNull];
		if (!isNull _lastButton && { ctrlShown ctrlParentControlsGroup _lastButton }) exitWith { ctrlSetFocus _lastButton };
		ctrlSetFocus ((_display displayCtrl A3A_IDC_TEAMLEADERBUILDERMAIN) controlsGroupCtrl A3A_IDC_TEAMLEADERBUILDINGGROUP);
	};
	case ("onLoad"):
    {
		private _display = findDisplay A3A_IDD_TEAMLEADERDIALOG;
		private _parent = (_display displayCtrl A3A_IDC_TEAMLEADERBUILDERMAIN);
		private _buildControlsGroup = _parent controlsGroupCtrl A3A_IDC_TEAMLEADERBUILDINGGROUP;

		private _moneyCtrl = _display displayCtrl A3A_IDC_TEAMLEADERBUILDERMONEY;
		_moneyCtrl ctrlSetText format ["%1 €", A3A_building_EHDB # AVAILABLE_MONEY];

		private _buildableObjects = A3A_buildableObjects;

		private _boxWidth = round ((ctrlPosition _buildControlsGroup # 2) / GRID_W);
		private _itemsPerRow = floor ((_boxWidth - 6) / 36);			// minimum 32 + 4 grids per tile
		private _itemWidth = floor ((_boxWidth - 6 - 4*_itemsPerRow) / _itemsPerRow);

		//diag_log format ["Builder: boxWidth %1, itemsPerRow %2, itemWidth %3", _boxWidth, _itemsPerRow, _itemWidth];

		private _tiles = [];
		{
			_x params [
				["_className", "Land_Tyres_F"],
				["_price", 0],
				["_ability",""]
			];

			private _configClass = configFile >> "CfgVehicles" >> _className;
			private _displayName = getText (_configClass >> "displayName");
			private _editorPreview = getText (_configClass >> "editorPreview");
			private _model = getText (_configClass >> "model");

			private _hasVehiclePreview = fileExists _editorPreview;

            if (!_hasVehiclePreview) then {
                _editorPreview = A3A_PlaceHolder_NoVehiclePreview;
            };

			private _itemXpos = (4 + (4 + _itemWidth) * (_forEachIndex % _itemsPerRow)) * GRID_W;
			private _itemYpos = (floor (_forEachIndex / _itemsPerRow)) * (34 * GRID_H);

			//diag_log format ["Builder: Item %1, xpos %2, ypos %3", _forEachIndex, _itemXpos, _itemYPos];

			private _itemControlsGroup = _display ctrlCreate ["A3A_ControlsGroupNoScrollbars", A3A_IDC_TEAMLEADERBUILDITEMGROUP, _buildControlsGroup];
			_itemControlsGroup ctrlSetPosition[_itemXpos, _itemYpos, _itemWidth * GRID_W, 30 * GRID_H];
			_itemControlsGroup ctrlSetFade 1;
			_itemControlsGroup ctrlCommit 0;

			private _previewPicture = _display ctrlCreate ["A3A_Picture", A3A_IDC_TEAMLEADERBUILDIMAGEPREVIEW, _itemControlsGroup];
			_previewPicture ctrlSetPosition [0, 0, _itemWidth * GRID_W, 24 * GRID_H];
			_previewPicture ctrlSetText _editorPreview;
			_previewPicture ctrlCommit 0;

			private _button = _display ctrlCreate ["A3A_ButtonSmallText", A3A_IDC_TEAMLEADERBUILDBUTTON, _itemControlsGroup];
			_button ctrlSetPosition [0, 24 * GRID_H, _itemWidth * GRID_W, 6 * GRID_H];
			_button ctrlSetText _displayName;
			_button setVariable ["className", _className];
			_button setVariable ["model", _model];
			_button setVariable ["price", _price];
			_button ctrlSetTooltip format ["%1\n%2", _displayName, _className];
			_button ctrlCommit 0;
			if (_ability isEqualTo "helipad" && {((((["Synd_HQ"] + outposts + seaports + airportsX + factories + resourcesX) select {sidesX getVariable [_x,sideUnknown] == teamPlayer}) apply {getMarkerPos _x}) inAreaArray [getPosATL player, 75, 75]) isEqualTo []}) then {
				_button ctrlEnable false;
				_button ctrlSetTooltip localize "STR_antistasi_teamleader_placer_cannotBuildHelipad";
			};

			_button ctrlAddEventHandler ["ButtonDown", {
				params ["_control"];

				if(isNil "A3A_building_EHDB") then {
					// how the fuck did you do this? No databases?
					call A3A_initBuildingDB;
				};

				ctrlParent _control setVariable ["A3A_lastBuildButton", _control];		// focus target when leaving the filter

				private _object = (A3A_building_EHDB # BUILD_OBJECT_TEMP_OBJECT);
				private _className = _control getVariable ["className", "Land_Tyres_F"];
				if (_className == typeof _object) exitWith {};			// refire, potentially caused by hitting space

				private _price = _control getVariable ["price", 0];
				private _supply = A3A_building_EHDB # AVAILABLE_MONEY;
				if (_price > _supply) exitWith {};			// TODO: Should disable buttons based on available money?

				A3A_building_EHDB set [BUILD_OBJECT_SELECTED_STRING, _className];		// why does this exist?
				A3A_building_EHDB set [OBJECT_PRICE, _price];

				private _vehPos =  getPosATL _object;
				private _vehDir = getDir _object;
				deleteVehicle _object;

				_object = _className createVehicleLocal [0,0,0];
				_object enableSimulation false;
				_object hideObject true;			// Otherwise it might not get checked, with some weird input combo
				_object setPos _vehPos;
				_object setDir _vehDir;
				A3A_building_EHDB set [BUILD_OBJECT_TEMP_OBJECT, _object];
				call (A3A_building_EHDB # UPDATE_BB);
			}];

			if (_price isNotEqualTo 0) then {
				private _priceText = _display ctrlCreate ["A3A_InfoTextRight", -1, _itemControlsGroup];
				_priceText ctrlSetPosition[(_itemWidth - 21) * GRID_W, 20 * GRID_H, 20 * GRID_W, 3 * GRID_H];
				_priceText ctrlSetText format ["%1 €",_price];
				_priceText ctrlCommit 0;
			};

			private _buildTime = _display ctrlCreate ["A3A_PictureStroke", -1, _itemControlsGroup];
			_buildTime ctrlSetPosition[1 * GRID_W, 19 * GRID_H, 4 * GRID_W, 4 * GRID_H];
			_buildTime ctrlSetText A3A_Icon_Construct;
			_buildTime ctrlCommit 0;

			// show stuff
			_itemControlsGroup ctrlSetFade 0;
            _itemControlsGroup ctrlCommit 0.1;

			_tiles pushBack [_itemControlsGroup, toLower (_displayName + " " + _className)];
		} forEach _buildableObjects;

		_display setVariable ["A3A_buildTileLayout", [_itemsPerRow, _itemWidth]];
		_display setVariable ["A3A_buildTiles", _tiles];
		["filter"] call A3A_GUI_fnc_teamLeaderRTSPlacerDialog;			// in case something was typed while the tiles were created

		// Filter field: stop the camera from moving while typing, the camera keys would otherwise pan it
		private _filterCtrl = _display displayCtrl A3A_IDC_TEAMLEADERBUILDERFILTER;
		_filterCtrl ctrlAddEventHandler ["SetFocus", { A3A_cam camCommand "manual off" }];

		// Panel area includes the title bar with the filter field
		_display setVariable ["A3A_isMouseOverPanel", {
			params ["_display"];
			private _titleHeight = ctrlPosition (_display displayCtrl A3A_IDC_TEAMLEADERBUILDERMONEY) # 3;
			ctrlPosition (_display displayCtrl A3A_IDC_TEAMLEADERBUILDERMAIN) params ["_xpos", "_ypos", "_width", "_height"];
			_ypos = _ypos - _titleHeight;
			_height = _height + _titleHeight;
			getMousePosition inArea [[_xpos + _width/2, _ypos + _height/2], _width/2, _height/2, 0, true];
		}];

		// Clicking into the world while typing hands the keyboard back to the placer
		_display displayAddEventHandler ["MouseButtonDown", {
			params ["_display"];
			if (focusedCtrl _display != _display displayCtrl A3A_IDC_TEAMLEADERBUILDERFILTER) exitWith {};
			if ([_display] call (_display getVariable "A3A_isMouseOverPanel")) exitWith {};
			["releaseFilterFocus"] call A3A_GUI_fnc_teamLeaderRTSPlacerDialog;
		}];

		// EH to block camera zoom while mouse is over the selection dialog or the filter is being typed in
		_display displayAddEventHandler ["MouseMoving", {

			params[ "_display" ];

			private _isMouseInArea = [_display] call (_display getVariable "A3A_isMouseOverPanel");
			private _isTyping = focusedCtrl _display == _display displayCtrl A3A_IDC_TEAMLEADERBUILDERFILTER;

			if (_isMouseInArea || _isTyping) then {
				A3A_cam camCommand "manual off";
			} else {
				A3A_cam camCommand "manual on";
			};

		}];

		// _txt = _display ctrlCreate[ "A3A_StructuredText", -1];
		// _txt ctrlSetPosition[ (1.4 * safeZoneX) + safeZoneW, -0.65 * safeZoneY, 0.5, 0.3];			// funkiness because I don't want to deal with dialogs anymore tonight
		// _txt ctrlCommit 0;
		// _txt ctrlSetStructuredText parseText localize "STR_antistasi_teamleader_placer_placer_info";
	};
	default
    {
        // Log error if attempting to call a mode that doesn't exist
        Error_1("BuyVehicleDialog mode does not exist: %1", _mode);
    };
};
