///|
/// Result of reading a `moon.mod`: the metadata plus whatever `moon_config`
/// complained about, left for the caller to report.
pub(all) struct ParsedMoonMod {
  info : ModuleInfo
  /// Empty when the source is clean.
  errors : Array[String]
}

///|
/// First field named `key`. `moon_config` normalizes `preferred_target` to
/// `preferred-target` at the top level but keeps the underscore inside
/// `options(...)`, so both spellings are accepted.
fn find_field(
  fields : @vector.Vector[(String, @moon_config.Ast)],
  key : String,
) -> @moon_config.Ast? {
  let alt = key.replace_all(old="-", new="_")
  for (name, value) in fields {
    if name == key || name == alt {
      return Some(value)
    }
  }
  None
}

///|
fn field_str(
  fields : @vector.Vector[(String, @moon_config.Ast)],
  key : String,
) -> String {
  match find_field(fields, key) {
    Some(@moon_config.Str(value, ..)) => unescape(value)
    _ => ""
  }
}

///|
fn field_strs(
  fields : @vector.Vector[(String, @moon_config.Ast)],
  key : String,
) -> Array[String] {
  match find_field(fields, key) {
    Some(@moon_config.Str(value, ..)) => [unescape(value)]
    Some(@moon_config.Arr(items, ..)) =>
      items
      .to_array()
      .map(fn(item) {
        match (item : @moon_config.Ast) {
          @moon_config.Str(value, ..) => unescape(value)
          _ => ""
        }
      })
    _ => []
  }
}

///|
fn read_deps(
  fields : @vector.Vector[(String, @moon_config.Ast)],
) -> Array[Dependency] {
  match find_field(fields, "deps") {
    Some(@moon_config.Obj(deps, ..)) =>
      deps
      .to_array()
      .map(fn(dep) {
        let (name, value) = dep
        {
          name,
          version: match (value : @moon_config.Ast) {
            @moon_config.Str(version, ..) => unescape(version)
            _ => ""
          },
        }
      })
    _ => []
  }
}

///|
/// Parse `moon.mod` source into `ModuleInfo`.
///
/// The DSL is `moonbitlang/moon_config`'s job, including the diagnostics for
/// duplicate and unknown keys; nothing here re-implements it.
pub fn parse_moon_mod(
  name~ : String = "moon.mod",
  source : String,
) -> ParsedMoonMod {
  let (ast, reports) = @moon_config.parse_moon_mod(name~, source)
  let info = match (ast : @moon_config.Ast) {
    @moon_config.Obj(fields, ..) =>
      {
        name: field_str(fields, "name"),
        version: field_str(fields, "version"),
        description: field_str(fields, "description"),
        license: field_str(fields, "license"),
        repository: field_str(fields, "repository"),
        readme: field_str(fields, "readme"),
        keywords: field_strs(fields, "keywords"),
        preferred_target: field_str(fields, "preferred-target"),
        supported_targets: field_strs(fields, "supported-targets"),
        deps: read_deps(fields),
      }
    _ => ModuleInfo::empty()
  }
  { info, errors: reports.map(report => report.msg), }
}
