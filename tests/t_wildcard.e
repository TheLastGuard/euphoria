include std/wildcard.e
include std/unittest.e

test_equal("is_match()", 1, is_match("A?B*", "AQBXXYY"))
test_equal("is_match()", 0, is_match("A?BZ*", "AQBXXYY"))
test_equal("is_match()", 0, is_match("A*B*C", "a111b222c"))

-- TODO: test the case sensitivity based on platform
test_equal("wildcard_file()", 1, wildcard_file("AB*CD.?", "AB123CD.e"))
test_equal("wildcard_file()", 0, wildcard_file("AB*CD.?", "abcd.ex"))

test_report()

