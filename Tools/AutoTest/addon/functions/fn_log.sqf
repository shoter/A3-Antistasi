/*
    Writes one machine-readable line to the server RPT for launch_tests.ps1:
        A3A_TEST|<kind>|<field>|<field>...

    Arguments:
        0: STRING - line kind (PHASE, PLAN, BEGIN, ASSERT, INFO, RESULT, DONE, FATAL)
        1: ARRAY  - fields, any type; '|' and line breaks are replaced so a field never splits

    Maintainer: Shoter
*/
params ["_kind", ["_fields", []]];

private _parts = ["A3A_TEST", _kind];
{
    private _s = if (_x isEqualType "") then { _x } else { str _x };
    _parts pushBack (_s regexReplace ["[|\r\n]+", " "]);
} forEach _fields;

diag_log text (_parts joinString "|");
