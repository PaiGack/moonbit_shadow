///|
test "unescape decodes moonbit escapes" {
  assert_eq(@mooninfo.unescape("a\\nb"), "a\nb")
  assert_eq(@mooninfo.unescape("a\\\"b\\\"c"), "a\"b\"c")
  assert_eq(@mooninfo.unescape("back\\\\slash"), "back\\slash")
  assert_eq(@mooninfo.unescape("tab\\there"), "tab\there")
}

///|
test "unescape leaves plain text and unknown escapes alone" {
  assert_eq(@mooninfo.unescape("plain text"), "plain text")
  assert_eq(@mooninfo.unescape("a\\qb"), "a\\qb")
}

///|
test "unescape decodes every escape the moon.mod lexer accepts" {
  assert_eq(@mooninfo.unescape("\\u{1F600}"), "\u{1F600}")
  assert_eq(@mooninfo.unescape("\\u0041"), "A")
  assert_eq(@mooninfo.unescape("\\x41"), "A")
  assert_eq(@mooninfo.unescape("\\o101"), "A")
  assert_eq(@mooninfo.unescape("\\b\\f\\v\\0").length(), 4)
}

///|
test "a malformed escape is kept as text" {
  assert_eq(@mooninfo.unescape("a\\u{ZZ}b"), "a\\u{ZZ}b")
  assert_eq(@mooninfo.unescape("a\\x4z"), "a\\x4z")
  assert_eq(@mooninfo.unescape("trailing\\"), "trailing\\")
}

///|
test "unescape undoes quote" {
  // What has to hold is the direction the generator uses: a value decoded once,
  // then quoted for source, comes back unchanged. `unescape` takes the literal's
  // contents, quotes included, which is what the lexer records.
  for sample in ["plain", "a \"quoted\" thing", "line1\nline2", "back\\slash"] {
    let quoted = @mooninfo.quote(sample)
    let inner = quoted[1:quoted.length() - 1].to_owned()
    assert_eq(@mooninfo.unescape(inner), sample)
  }
}

///|
test "an escaped unicode sequence survives a round trip" {
  // The bug this replaces: `\u{...}` was kept verbatim by `unescape` but
  // escaped again by `quote`, so every regeneration added a backslash.
  let raw = "\\\\u{1F600}"
  assert_eq(@mooninfo.unescape(raw), "\\u{1F600}")
  assert_eq(@mooninfo.quote(@mooninfo.unescape(raw)), "\"\\\\u{1F600}\"")
}
