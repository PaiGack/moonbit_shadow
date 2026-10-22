///|
test "render escapes quotes and newlines" {
  let info : @core.ModuleInfo = {
    ..@core.ModuleInfo::empty(),
    name: "acme/demo",
    version: "1.0.0",
    description: "line1\nline2 \"quoted\"",
    keywords: ["a\"b"],
    deps: [{ name: "moonbitlang/x", version: "0.4.6", }],
  }
  let out = @core.render_module_info(info)
  assert_true(out.contains("description: \"line1\\nline2 \\\"quoted\\\"\","))
  assert_true(out.contains("keywords: [\"a\\\"b\"],"))
  assert_true(out.contains("{ name: \"moonbitlang/x\", version: \"0.4.6\" },"))
  assert_true(out.contains("pub fn module_info() -> @core.ModuleInfo {"))
}

///|
test "render without deps stays on one line" {
  let out = @core.render_module_info(@core.ModuleInfo::empty())
  assert_true(out.contains("deps: [],"))
  assert_false(out.contains("deps: [\n"))
}

///|
test "render round trips through the parser" {
  let source =
    #|name = "acme/demo"
    #|version = "1.0.0"
    #|description = "a \"quoted\" thing"
    #|import {
    #|  "moonbitlang/x@0.4.6",
    #|}
  let out = @core.render_module_info(@core.parse_moon_mod(source).info)
  assert_true(out.contains("name: \"acme/demo\","))
  assert_true(out.contains("description: \"a \\\"quoted\\\" thing\","))
  assert_true(out.contains("{ name: \"moonbitlang/x\", version: \"0.4.6\" },"))
}
