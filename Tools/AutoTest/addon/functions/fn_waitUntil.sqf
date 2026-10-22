/*
    Waits until the condition returns true or the timeout passes. Scheduled code only.

    Arguments:
        0: CODE   - condition, called every interval
        1: NUMBER - timeout in seconds
        2: NUMBER - check interval in seconds, optional (default 0.5)

    Return: BOOL - true when the condition became true, false on timeout

    Maintainer: Shoter
*/
params ["_condition", "_timeout", ["_interval", 0.5]];

private _end = diag_tickTime + _timeout;
waitUntil { sleep _interval; call _condition || diag_tickTime > _end };
call _condition;
