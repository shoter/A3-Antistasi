/*
Description:
    Server-side function to finish unbuilt constructions that nobody built before their timeout.
    The timeout (5-30 minutes by price) is set in placeBuilderObjects.
    Called every 30 seconds by a loop started in initServer

Environment: Server, scheduled
Arguments: None
*/

// Protection required to prevent running in parallel with buildingComplete
// Should be fine run in parallel with placeBuilderObjects because it only adds to the end

isNil {
    private _expired = A3A_unbuiltObjects select { time > _x getVariable ["A3A_build_timeout", 1e9] };
    { [_x, true] call A3A_fnc_buildingComplete } forEach _expired;          // removes it from A3A_unbuiltObjects and builds or repairs
};
