///|
/// Result of `parse_moon_mod`.
pub(all) struct ParsedMoonMod {
  info : @modinfo_types.ModuleInfo
  /// Config problem reported by `moon_config`, empty when the source is clean.
  errors : Array[String]
}

///|
fn ast_str(
  fields : @vector.Vector[(String, @moon_config.Ast)],
  key : String,
) -> String {
  match find_field(fields, key) {
    Some(@moon_config.Str(value, ..)) => value
    _ => ""
  }
}

///|
fn ast_str_array(
  fields : @vector.Vector[(String, @moon_config.Ast)],
  key : String,
) -> Array[String] {
  match find_field(fields, key) {
    Some(@moon_config.Arr(items, ..)) =>
      items
      .to_array()
      .map(fn(item) {
        match (item : @moon_config.Ast) {
          @moon_config.Str(value, ..) => value
          _ => ""
        }
      })
    Some(@moon_config.Str(value, ..)) => [value]
    _ => []
  }
}

///|
/// `moon_config` normalizes `preferred_target = ...` to `preferred-target` but
/// leaves the underscore form untouched inside `options(...)`, so accept both.
fn find_field(
  fields : @vector.Vector[(String, @moon_config.Ast)],
  key : String,
) -> @moon_config.Ast? {
  let alt = key.replace_all(old="-", new="_")
  let mut found : @moon_config.Ast? = None
  for field in fields {
    if (field.0 == key || field.0 == alt) && found is None {
      found = Some(field.1)
    }
  }
  found
}

///|
/// Parse `moon.mod` source into `ModuleInfo`.
///
/// The DSL is handled by `moonbitlang/moon_config`, so diagnostics for
/// duplicate or unexpected keys come along for free instead of being
/// re-implemented here.
pub fn parse_moon_mod(
  name~ : String = "moon.mod",
  source : String,
) -> ParsedMoonMod {
  let (ast, reports) = @moon_config.parse_moon_mod(name~, source)
  let info = match (ast : @moon_config.Ast) {
    @moon_config.Obj(fields, ..) =>
      (
        {
          name: ast_str(fields, "name"),
          version: ast_str(fields, "version"),
          description: ast_str(fields, "description"),
          license: ast_str(fields, "license"),
          repository: ast_str(fields, "repository"),
          readme: ast_str(fields, "readme"),
          keywords: ast_str_array(fields, "keywords"),
          preferred_target: ast_str(fields, "preferred-target"),
          supported_targets: ast_str_array(fields, "supported-targets"),
          deps: match find_field(fields, "deps") {
            Some(@moon_config.Obj(deps, ..)) =>
              deps
              .to_array()
              .map(fn(dep) { { name: dep.0, version: ast_str_value(dep.1), } })
            _ => []
          },
        } : @modinfo_types.ModuleInfo)
    _ => @modinfo_types.ModuleInfo::empty()
  }
  { info, errors: reports.map(report => report.msg), }
}

///|
fn ast_str_value(ast : @moon_config.Ast) -> String {
  match (ast : @moon_config.Ast) {
    @moon_config.Str(value, ..) => value
    _ => ""
  }
}
