///|
test "dep lookup and long version" {
  let info : @modinfo_types.ModuleInfo = {
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
  assert_true(
    info.dep("moonbitlang/x")
    is Some({ name: "moonbitlang/x", version: "0.4.6", }),
  )
  assert_true(info.dep("moonbitlang/y") is None)
  assert_eq(info.to_long_version_string(), "acme/demo 1.2.3 demo module")
}

///|
test "empty info" {
  let info = @modinfo_types.ModuleInfo::empty()
  assert_eq(info.name, "")
  assert_eq(info.to_long_version_string().trim(), "")
}
