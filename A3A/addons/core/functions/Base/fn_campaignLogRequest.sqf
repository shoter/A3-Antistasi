/*
Maintainer: Shoter
    Sends a client the chronicle entries it has not seen yet, so opening the Chronicle tab only costs the delta.
    The reply lands in the "receive" mode of A3A_GUI_fnc_chronicleTab on the requesting client.

Arguments:
    <NUMBER> clientOwner of the requesting client
    <NUMBER> Sequence number of the newest entry the client already has, 0 for none

Return Value:
    <nil>

Scope: Server
Environment: Any
Public: No
Dependencies: A3A_GUI_fnc_chronicleTab

Example:
    [clientOwner, A3A_chronicleSeq] remoteExecCall ["A3A_fnc_campaignLogRequest", 2];
*/
#include "..\..\script_component.hpp"
FIX_LINE_NUMBERS()

if !(isServer) exitWith { Error("Attempted to call server function as non-server") };

params [["_client", 0, [0]], ["_knownSeq", 0, [0]]];

private _entries = A3A_campaignLog select { (_x select 0) > _knownSeq };
Debug_2("Sending %1 chronicle entries to client %2", count _entries, _client);
["receive", [A3A_campaignLogVersion, _entries]] remoteExecCall ["A3A_GUI_fnc_chronicleTab", _client];
