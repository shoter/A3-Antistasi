// @description: Harness self-test, expected FAIL: two failed assertions
// @timeout: 30
#include "\x\A3A_autotest\test.hpp"

ASSERT(1 == 2, "one equals two");
ASSERT_EQ(count citiesX, -1, "city count");
