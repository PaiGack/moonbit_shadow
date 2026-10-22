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
