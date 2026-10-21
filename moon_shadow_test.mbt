///|
test "current() reads the moon.mod of this module" {
  let info = @moon_shadow.current()
  assert_eq(info.name, "username/moon_shadow")
  assert_eq(info.version, "0.1.0")
  assert_eq(info.license, "Apache-2.0")
}

///|
test "long_version joins name and version" {
  assert_eq(@moon_shadow.current().long_version(), "username/moon_shadow@0.1.0")
}
