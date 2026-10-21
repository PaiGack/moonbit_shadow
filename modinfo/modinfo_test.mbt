///|
test "current reads generated moon.mod info" {
  let info = @modinfo.current()
  assert_eq(info.name, "nrzhangsan/moon_shadow")
  assert_eq(info.version, "0.1.0")
  assert_eq(info.license, "Apache-2.0")
  assert_true(info.dep("moonbitlang/moon_config") is Some(_))
}
