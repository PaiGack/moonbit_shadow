///|
fn quote(value : String) -> String {
  let buf = StringBuilder()
  buf.write_char('"')
  for ch in value {
    match ch {
      '"' => buf.write_string("\\\"")
      '\\' => buf.write_string("\\\\")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      _ => buf.write_char(ch)
    }
  }
  buf.write_char('"')
  buf.to_string()
}

///|
fn quote_array(values : Array[String]) -> String {
  "[" + values.map(quote).join(", ") + "]"
}

///|
/// Render the implementation that `dev_build` writes into a virtual package
/// implementation: a `module_info()` accessor returning `@core.ModuleInfo`.
///
/// It is a function rather than a `let` on purpose: `moon` type-checks a
/// virtual package's implementations against its `pkg.mbti`, and only function
/// signatures in the `pkg.mbti` form survive that check for a type coming from
/// another package.
pub fn render_module_info(info : ModuleInfo) -> String {
  let lines : Array[String] = [
    "///|",
    "/// Generated from `moon.mod`. Keep in sync when `moon.mod` changes.",
    "pub fn module_info() -> @core.ModuleInfo {",
    "  {",
    "    name: \{quote(info.name)},",
    "    version: \{quote(info.version)},",
    "    description: \{quote(info.description)},",
    "    license: \{quote(info.license)},",
    "    repository: \{quote(info.repository)},",
    "    readme: \{quote(info.readme)},",
    "    keywords: \{quote_array(info.keywords)},",
    "    preferred_target: \{quote(info.preferred_target)},",
    "    supported_targets: \{quote_array(info.supported_targets)},",
  ]
  if info.deps.is_empty() {
    lines.push("    deps: [],")
  } else if info.deps.length() == 1 {
    // `moon fmt` keeps a single-element array on one line.
    let dep = info.deps[0]
    lines.push(
      "    deps: [{ name: \{quote(dep.name)}, version: \{quote(dep.version)}, }],",
    )
  } else {
    lines.push("    deps: [")
    for dep in info.deps {
      lines.push(
        // Trailing comma inside the braces is what `moon fmt` leaves behind.
        "      { name: \{quote(dep.name)}, version: \{quote(dep.version)}, },",
      )
    }
    lines.push("    ],")
  }
  lines.push("  }")
  lines.push("}")
  lines.join("\n") + "\n"
}
