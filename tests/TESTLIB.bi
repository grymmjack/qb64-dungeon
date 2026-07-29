' ============================================================================
'  TESTLIB.bi -- shared state for the headless engine test harness.
'  Include FIRST in every TEST-*.bas (before ENGINE.BI, which it does not need).
' ============================================================================

' NOTE: counters are T_NPASS/T_NFAIL, not T_PASS/T_FAIL -- QB64 identifiers are
' CASE-INSENSITIVE, so a T_FAIL variable would collide with the T_Fail SUB below
' ("Name already in use", which does not print the word "error").
DIM SHARED T_NPASS AS INTEGER         ' assertions that held
DIM SHARED T_NFAIL AS INTEGER         ' assertions that did not
DIM SHARED T_SUITE AS STRING          ' name of the file under test
DIM SHARED T_GRPNAME AS STRING          ' current group label (printed once, on first failure; NOT T_GROUP -- collides with SUB T_Group)
DIM SHARED T_GRPSHOWN AS INTEGER
