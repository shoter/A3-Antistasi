/*
    A3A_fnc_taskSetState
    Worker function to set fail & success states for A3A and BIS tasks

    Parameters:
    <STRING> unique task ID
    <STRING> task type (eg. LOG, RES, CONVOY)
    <STRING> new state, should be FAILED or SUCCEEDED
    <BOOL> default false, if true, also sets reverse state for twin BIS task (taskID+"B")
*/

params ["_taskId", "_taskType", "_state", ["_isTwin", false]];

[_taskId, _taskType, _state] remoteExecCall ["A3A_fnc_taskUpdate", 2];
[_taskId, _state] call BIS_fnc_taskSetState;

// Chronicle entry for mission outcomes. Attacks and construction tasks are logged where they end.
if (isServer && {_state in ["SUCCEEDED", "FAILED"]} && {!(_taskType in ["rebelAttack", "DEF_HQ", "invaderPunish", "Mines", "outpostsFIA"])}) then {
    private _description = [_taskId] call BIS_fnc_taskDescription;
    private _title = if (_description isEqualType []) then { _description param [1, ""] } else { "" };
    if (_title isEqualType []) then { _title = _title param [0, ""] };
    if !(_title isEqualType "") then { _title = "" };

    private _destination = [_taskId] call BIS_fnc_taskDestination;
    if (isNil "_destination") then { _destination = [] };
    private _position = call {
        if (_destination isEqualType []) exitWith { _destination };
        if (_destination isEqualType objNull && {!isNull _destination}) exitWith { getPosATL _destination };
        if (_destination isEqualType "" && {markerShape _destination != ""}) exitWith { markerPos _destination };
        []
    };

    private _succeeded = _state == "SUCCEEDED";
    private _type = ["missionFailed", "missionSucceeded"] select _succeeded;
    if (_position isEqualTo []) then {
        [_type, "", [_title]] call A3A_fnc_campaignLogAdd;
    } else {
        // Nearby rebel players get the credit for a success
        [_type, _position, [_title], ["", _position] select _succeeded] call A3A_fnc_campaignLogAdd;
    };
};

if (!_isTwin) exitWith {};
private _state2 = switch (_state) do {
    case "SUCCEEDED": {"FAILED"};
    case "FAILED": {"SUCCEEDED"};
    default {_state};
};
[_taskId+"B", _state2] call BIS_fnc_taskSetState;
