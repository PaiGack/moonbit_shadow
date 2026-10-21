///|
fn escape(value : String) -> String {
  value
  .replace_all(old="\\", new="\\\\")
  .replace_all(old="\"", new="\\\"")
  .replace_all(old="\n", new="\\n")
  .replace_all(old="\r", new="\\r")
  .replace_all(old="\t", new="\\t")
}

///|
fn render_str_array(values : Array[String]) -> String {
  let items = values.map(fn(v) {
    let q = "\""
    q + escape(v) + q
  })
  "[" + items.join(", ") + "]"
}

///|
/// Render the module info block that `dev_build` writes into a virtual
/// package implementation, as a `pub let module_info : @modinfo.ModuleInfo`.
pub fn render_module_info(info : @modinfo_types.ModuleInfo) -> String {
  let deps = info.deps.map(fn(dep) {
    "{ name: \"\{escape(dep.name)}\", version: \"\{escape(dep.version)}\" }"
  })
  let body = "///|" +
    "\npub let module_info : @modinfo_types.ModuleInfo = {" +
    "\n  name: \"\{escape(info.name)}\"," +
    "\n  version: \"\{escape(info.version)}\"," +
    "\n  description: \"\{escape(info.description)}\"," +
    "\n  license: \"\{escape(info.license)}\"," +
    "\n  repository: \"\{escape(info.repository)}\"," +
    "\n  readme: \"\{escape(info.readme)}\"," +
    "\n  keywords: \{render_str_array(info.keywords)}," +
    "\n  preferred_target: \"\{escape(info.preferred_target)}\"," +
    "\n  supported_targets: \{render_str_array(info.supported_targets)}," +
    "\n  deps: [" +
    (if deps.is_empty() {
      ""
    } else {
      "\n    " + deps.join(",\n    ") + ",\n  "
    }) +
    "]," +
    "\n}" +
    "\n"
  body
}
