///|
test "unescape decodes moonbit escapes" {
  assert_eq(@core.unescape("a\\nb"), "a\nb")
  assert_eq(@core.unescape("a\\\"b\\\"c"), "a\"b\"c")
  assert_eq(@core.unescape("back\\\\slash"), "back\\slash")
  assert_eq(@core.unescape("tab\\there"), "tab\there")
}

///|
test "unescape leaves plain text and unknown escapes alone" {
  assert_eq(@core.unescape("plain text"), "plain text")
  assert_eq(@core.unescape("a\\qb"), "a\\qb")
}
