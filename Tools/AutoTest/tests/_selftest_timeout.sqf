// @description: Harness self-test, expected TIMEOUT: never finishes
// @timeout: 5
#include "\x\A3A_autotest\test.hpp"

waitUntil { sleep 1; false };
