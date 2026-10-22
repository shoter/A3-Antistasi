// @description: Harness self-test, expected NOT RUN: the save does not exist, the run stops with FATAL
// @timeout: 30
// @start: load does_not_exist
#include "\x\A3A_autotest\test.hpp"

FAIL("this test should never run");
