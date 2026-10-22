///|
test "render escapes quotes and newlines" {
  let info : @mooninfo.ModuleInfo = {
    ..@mooninfo.ModuleInfo::empty(),
    name: "acme/demo",
    version: "1.0.0",
    description: "line1\nline2 \"quoted\"",
    keywords: ["a\"b"],
    deps: [
      { name: "moonbitlang/x", version: "0.4.6", },
      { name: "moonbitlang/moon_config", version: "0.4.4", },
    ],
  }
  let out = @mooninfo.render_module_info(info, pkg_path="mooninfo")
  assert_true(out.contains("description: \"line1\\nline2 \\\"quoted\\\"\","))
  assert_true(out.contains("keywords: [\"a\\\"b\"],"))
  assert_true(out.contains("{ name: \"moonbitlang/x\", version: \"0.4.6\" },"))
  assert_true(out.contains("pub fn module_info() -> @mooninfo.ModuleInfo {"))
}

///|
test "render puts every dep on its own line" {
  let info : @mooninfo.ModuleInfo = {
    ..@mooninfo.ModuleInfo::empty(),
    name: "acme/demo",
    deps: [{ name: "moonbitlang/x", version: "0.4.6", }],
  }
  let out = @mooninfo.render_module_info(info, pkg_path="mooninfo")
  assert_true(
    out.contains(
      "    deps: [\n      { name: \"moonbitlang/x\", version: \"0.4.6\" },\n    ],\n",
    ),
  )
}

///|
test "render without deps stays on one line" {
  let out = @mooninfo.render_module_info(
    @mooninfo.ModuleInfo::empty(),
    pkg_path="mooninfo",
  )
  assert_true(out.contains("deps: [],"))
  assert_false(out.contains("deps: [\n"))
}

///|
test "render round trips through the parser" {
  let info : @mooninfo.ModuleInfo = {
    ..@mooninfo.ModuleInfo::empty(),
    name: "acme/demo",
    version: "1.0.0",
    description: "a \"quoted\" thing",
    deps: [
      { name: "moonbitlang/x", version: "0.4.6", },
      { name: "moonbitlang/moon_config", version: "0.4.4", },
    ],
  }
  let out = @mooninfo.render_module_info(info, pkg_path="mooninfo")
  assert_true(out.contains("name: \"acme/demo\","))
  assert_true(out.contains("description: \"a \\\"quoted\\\" thing\","))
  assert_true(out.contains("{ name: \"moonbitlang/x\", version: \"0.4.6\" },"))
}
