///|
test "describe comes from the compiled artifact" {
  let text = @moon_shadow_example.describe()
  assert_true(text.contains("nrzhangsan/moon_shadow"))
  assert_true(text.contains("0.1.0"))
}
