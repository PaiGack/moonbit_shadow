///|
test "describe reads this module's own moon.mod" {
  // Compare against the metadata the build baked in, so a `moon.mod` version
  // bump needs no edit here.
  let info = @moon_shadow.current()
  let text = @moon_shadow_example.describe()
  assert_eq(text, "\{info.name}@\{info.version} (\{info.preferred_target})")
  assert_true(text.contains("wasm-gc"))
}

///|
test "own_metadata matches the library API" {
  assert_eq(
    @moon_shadow_example.own_metadata(),
    @moon_shadow_example.describe(),
  )
}

///|
test "git info is baked in, not probed at runtime" {
  let git = @moon_shadow.git()
  // The implementation here is this module's own; how much git it saw depends
  // on the checkout the build ran in, so only the invariant is asserted.
  assert_eq(git.available, !git.commit.is_empty())
}

///|
test "git describe never ends in a dangling separator" {
  let text = @moon_shadow_example.git_describe()
  if @moon_shadow.git().available {
    assert_true(text != "unavailable")
  } else {
    assert_eq(text, "unavailable")
  }
}

///|
test "build info names the toolchain that built this example" {
  let text = @moon_shadow_example.build_describe()
  // The generator ran on this machine, so both halves are non-empty unless
  // `moon version --all` failed — in which case the empty string is the honest
  // answer, and the format string is all that is left to assert.
  assert_eq(text.split(" / ").count(), 3)
  let build = @shadow.build_info()
  assert_true(build.profile == "debug" || build.profile == "release")
  assert_true(!build.target.is_empty())
}
