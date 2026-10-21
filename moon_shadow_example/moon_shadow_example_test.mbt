///|
test "example reads its own moon.mod metadata" {
  assert_eq(
    @moon_shadow_example.describe(),
    "username/moon_shadow_example@0.2.0 (wasm)",
  )
}
