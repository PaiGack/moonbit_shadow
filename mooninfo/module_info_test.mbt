///|
fn demo_info() -> @mooninfo.ModuleInfo {
  {
    name: "acme/demo",
    version: "1.2.3",
    description: "demo module",
    license: "MIT",
    repository: "",
    readme: "",
    keywords: [],
    preferred_target: "",
    supported_targets: [],
    deps: [{ name: "moonbitlang/x", version: "0.4.6", }],
  }
}

///|
test "dep lookup" {
  let info = demo_info()
  assert_true(
    info.dep("moonbitlang/x")
    is Some({ name: "moonbitlang/x", version: "0.4.6", }),
  )
  assert_true(info.dep("moonbitlang/y") is None)
}

///|
test "long version shapes" {
  assert_eq(demo_info().long_version(), "acme/demo@1.2.3")
  assert_eq(@mooninfo.ModuleInfo::empty().long_version(), "")
  assert_eq(demo_info().to_long_version_string(), "acme/demo 1.2.3 demo module")
}

///|
test "empty info" {
  let info = @mooninfo.ModuleInfo::empty()
  assert_eq(info.name, "")
  assert_eq(info.deps, [])
  assert_eq(info.to_long_version_string(), "")
}
