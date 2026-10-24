// @description: The 10-minute income report shows each line once, with its own numbers
// @timeout: 30
// @start: new
// @world: Altis
#include "\x\A3A_autotest\test.hpp"

// Occurrences of _needle in _text
private _countIn = {
    params ["_text", "_needle"];
    private _count = 0;
    private _pos = _text find _needle;
    while {_pos >= 0} do {
        _count = _count + 1;
        _text = _text select [_pos + count _needle];
        _pos = _text find _needle;
    };
    _count
};

private _incomeLine = format [localize "STR_A3A_fn_init_resourceCheck_income", (12.5) toFixed 1, 2400];
private _upgradeLine = format [localize "STR_A3A_fn_townUpgrades_income", 300, (1.5) toFixed 1];
private _taxLine = format [localize "STR_A3A_fn_init_resourceCheck_tax", 150];
private _arsenalLine = localize "STR_A3A_fn_init_resourceCheck_arsenal";

// Every optional line present: before the fix the report was pasted into the tax and upgrade lines
private _args = [12.5, 2400, 300, 1.5, 150, true, "Rifle X<br/>"];
private _full = _args call A3A_fnc_incomeReportText;
INFO(_full);
private _n1 = [_full, _incomeLine] call _countIn;
ASSERT_EQ(_n1, 1, "income line count (all lines)");
private _n2 = [_full, _upgradeLine] call _countIn;
ASSERT_EQ(_n2, 1, "town upgrade line count (all lines)");
private _n3 = [_full, _taxLine] call _countIn;
ASSERT_EQ(_n3, 1, "reward tax line count (all lines)");
private _n4 = [_full, _arsenalLine] call _countIn;
ASSERT_EQ(_n4, 1, "arsenal line count (all lines)");
private _n5 = [_full, "Rifle X"] call _countIn;
ASSERT_EQ(_n5, 1, "unlocked item count (all lines)");

// Tax only
_args = [12.5, 2400, 0, 0, 150, true, ""];
private _taxOnly = _args call A3A_fnc_incomeReportText;
private _n6 = [_taxOnly, _incomeLine] call _countIn;
ASSERT_EQ(_n6, 1, "income line count (tax only)");
private _n7 = [_taxOnly, _taxLine] call _countIn;
ASSERT_EQ(_n7, 1, "reward tax line count (tax only)");
private _n8 = [_taxOnly, _upgradeLine] call _countIn;
ASSERT_EQ(_n8, 0, "town upgrade line hidden without upgrades");

// Nothing optional: just the income line
_args = [12.5, 2400, 0, 0, 0, false, ""];
private _plain = _args call A3A_fnc_incomeReportText;
private _expected = "<t size='0.6' color='#C1C0BB'>" + _incomeLine;
ASSERT_EQ(_plain, _expected, "report without optional lines");
