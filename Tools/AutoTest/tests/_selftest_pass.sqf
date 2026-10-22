// @description: Harness self-test, expected PASS: waits for a condition and logs info
// @timeout: 30
#include "\x\A3A_autotest\test.hpp"

private _start = time;
private _ok = WAIT_UNTIL(time > _start + 2, 10);
ASSERT(_ok, "time advances on the server");
INFO("waited " + str (time - _start) + " s");
