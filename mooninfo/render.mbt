///|
/// MoonBit string literal for `value`, using only the escapes MoonBit's lexer
/// accepts.
///
/// The inverse of `unescape`: a value that went through `parse_moon_mod` and
/// comes back out here is decoded exactly once, so regenerating a generated
/// file never adds a backslash.
pub fn quote(value : String) -> String {
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
/// Render one struct literal field, e.g. `name: "acme/demo",`.
fn field(name : String, value : String) -> String {
  "    \{name}: \{value},"
}

///|
fn array_field(name : String, values : Array[String]) -> String {
  field(name, quote_array(values))
}

///|
/// Render the implementation that `dev_build` writes into a virtual package
/// implementation: a `module_info()` accessor returning `@pkg_alias.ModuleInfo`.
///
/// It is a function rather than a `let` on purpose: `moon` type-checks a
/// virtual package's implementations against its `pkg.mbti`, and only function
/// signatures in the `pkg.mbti` form survive that check for a type coming from
/// another package.
///
/// `pkg_path` is how the implementation package reaches this one. It is a
/// parameter because the implementation lives somewhere else and its hand
/// written `pkg.mbti` has to spell the type the same way: `mooninfo` from a
/// sibling package, `PaiGack/moon_shadow/mooninfo` from another module.
///
/// The output is `moon fmt` clean, so a regenerated file never shows up as a
/// diff just because the formatter has an opinion about commas.
pub fn render_module_info(info : ModuleInfo, pkg_path~ : String) -> String {
  let lines : Array[String] = [
    "///|",
    "/// Generated from `moon.mod`. Keep in sync when `moon.mod` changes.",
    "pub fn module_info() -> @\{pkg_path}.ModuleInfo {",
    "  {",
    field("name", quote(info.name)),
    field("version", quote(info.version)),
    field("description", quote(info.description)),
    field("license", quote(info.license)),
    field("repository", quote(info.repository)),
    field("readme", quote(info.readme)),
    array_field("keywords", info.keywords),
    field("preferred_target", quote(info.preferred_target)),
    array_field("supported_targets", info.supported_targets),
  ]
  if info.deps.is_empty() {
    lines.push(field("deps", "[]"))
  } else {
    lines.push("    deps: [")
    for dep in info.deps {
      lines.push(
        "      { name: \{quote(dep.name)}, version: \{quote(dep.version)} },",
      )
    }
    lines.push("    ],")
  }
  lines.push("  }")
  lines.push("}")
  lines.join("\n") + "\n"
}
