// Helpers for test scripts: #include "\x\A3A_autotest\test.hpp"
// Arma's preprocessor splits macro arguments on every comma, also inside [] and "" in some cases,
// so pass array literals or format calls through a local variable, or call the A3A_test_fnc_* functions directly.

#define ASSERT(COND,MSG) [COND, MSG, __LINE__] call A3A_test_fnc_assert
#define ASSERT_EQ(ACTUAL,EXPECTED,MSG) [ACTUAL, EXPECTED, MSG, __LINE__] call A3A_test_fnc_assertEqual
#define FAIL(MSG) [MSG, __LINE__] call A3A_test_fnc_fail
#define INFO(MSG) [MSG] call A3A_test_fnc_info
#define WAIT_UNTIL(COND,TIMEOUT) ([{COND}, TIMEOUT] call A3A_test_fnc_waitUntil)
