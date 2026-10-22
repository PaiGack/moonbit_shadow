///|
test "describe comes from the library artifact" {
  let text = @moon_shadow_example.describe()
  assert_true(text.contains("nrzhangsan/moon_shadow@0.1.0"))
  assert_true(text.contains("wasm-gc"))
}

///|
test "own_metadata comes from this module's shadow_impl" {
  let text = @moon_shadow_example.own_metadata()
  assert_true(text.contains("nrzhangsan/moon_shadow_example@0.2.0"))
  assert_true(text.contains("wasm-gc"))
}
