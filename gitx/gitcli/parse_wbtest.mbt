///|
/// `git log --format=%an%x09%ae%x09%cI%x09%D` -> the four fields.
test "log fields split on tabs" {
  let fields = split_fields(
    "Pai2s\tpai2s@example.com\t2026-10-23T16:30:59+08:00\tHEAD -> main, tag: v0.3.0",
  )
  assert_eq(fields[0], "Pai2s")
  assert_eq(fields[1], "pai2s@example.com")
  assert_eq(fields[2], "2026-10-23T16:30:59+08:00")
  assert_eq(fields[3], "HEAD -> main, tag: v0.3.0")
}

///|
test "an empty decoration is still a field" {
  let fields = split_fields("A\ta@b\t2026-01-01T00:00:00+00:00\t")
  assert_eq(fields.length(), 4)
  assert_eq(fields[3], "")
}

///|
/// The decoration is free text, so only the first three tabs are separators.
test "a tab in the decoration stays in the decoration" {
  let fields = split_fields("A\ta@b\t2026-01-01T00:00:00+00:00\ttag: v1\tx")
  assert_eq(fields[3], "tag: v1\tx")
}

///|
test "a tag is read out of the decoration" {
  assert_eq(tag_of("HEAD -> main, tag: v1.2.3, origin/main"), "v1.2.3")
  assert_eq(tag_of("tag: v1.2.3"), "v1.2.3")
  assert_eq(tag_of("HEAD -> main"), "")
  assert_eq(tag_of(""), "")
}

///|
test "ahead and behind come from rev-list --count" {
  assert_eq(track_counts("2\t3"), (2, 3))
  assert_eq(track_counts("0\t0"), (0, 0))
  // No upstream: git exits zero and prints nothing.
  assert_eq(track_counts(""), (0, 0))
}

///|
test "a commit id is forty hex characters" {
  assert_true(is_hex("6a42542c0a9432eef9080436203144f42c1b3475"))
  assert_false(is_hex("6a42542"))
  assert_false(is_hex("6a42542c0a9432eef9080436203144f42c1b347z"))
}

///|
test "short_of keeps seven characters" {
  assert_eq(short_of("6a42542c0a9432eef9080436203144f42c1b3475"), "6a42542")
  assert_eq(short_of("abc"), "abc")
}
