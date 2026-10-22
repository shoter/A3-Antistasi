// @description: Harness self-test, expected FAIL or ERROR: script error in the test
// @timeout: 30
#include "\x\A3A_autotest\test.hpp"

private _value = _undefinedVariable + 1;
ASSERT(_value == 1, "unreachable value check");
