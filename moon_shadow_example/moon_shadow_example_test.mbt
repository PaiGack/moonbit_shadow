///|
test "describe reads this module's own moon.mod" {
  let text = @moon_shadow_example.describe()
  assert_true(text.contains("nrzhangsan/moon_shadow_example@0.2.0"))
  assert_true(text.contains("wasm-gc"))
}

///|
test "own_metadata matches the library API" {
  assert_eq(
    @moon_shadow_example.own_metadata(),
    @moon_shadow_example.describe(),
  )
}
