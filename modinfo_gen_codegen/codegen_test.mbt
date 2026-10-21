///|
test "render keeps quotes and newlines escaped" {
  let info : @modinfo_types.ModuleInfo = {
    name: "acme/demo",
    version: "1.0.0",
    description: "line1\nline2 \"quoted\"",
    license: "",
    repository: "",
    readme: "",
    keywords: ["a\"b"],
    preferred_target: "",
    supported_targets: [],
    deps: [{ name: "moonbitlang/x", version: "0.4.6", }],
  }
  let out = @modinfo_gen_codegen.render_module_info(info)
  assert_true(out.contains("description: \"line1\\nline2 \\\"quoted\\\"\""))
  assert_true(out.contains("keywords: [\"a\\\"b\"]"))
  assert_true(out.contains("{ name: \"moonbitlang/x\", version: \"0.4.6\" }"))
  assert_true(
    out.contains("pub let module_info : @modinfo_types.ModuleInfo = {"),
  )
}

///|
test "render without deps" {
  let out = @modinfo_gen_codegen.render_module_info(
    @modinfo_types.ModuleInfo::empty(),
  )
  assert_true(out.contains("deps: [],"))
}
