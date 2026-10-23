///|
/// The whole implementation file: `module_info()` from `mooninfo`, plus
/// `git_info()`, which only `gen` knows how to shape.
///
/// Deterministic by construction — no timestamp, no random — so regenerating
/// from the same inputs yields no diff, and a committed `generated.mbt` never
/// makes the work tree dirty behind the user's back.
///
/// `git_path` is the full package path of `gitinfo`. A virtual
/// implementation's `pkg.mbti` is written by hand, so the generated file spells
/// the type the same way it does; a full path works no matter what aliases that
/// package happens to declare. `mooninfo`'s renderer takes its own path for the
/// same reason.
fn quoted_line(name : String, quoted : String) -> String {
  "    \{name}: \{quoted},"
}

///|
fn render(
  git : @gitinfo.GitInfo,
  module_block : String,
  toolchain_versions : (String, String),
  git_path~ : String,
) -> String {
  let at_git = "@" + git_path
  let lines : Array[String] = [module_block]
  lines.push("///|")
  lines.push("/// Generated from the git checkout this module was built in.")
  lines.push("pub fn git_info() -> \{at_git}.GitInfo {")
  lines.push("  {")
  lines.push("    available: \{git.available},")
  for
    pair in [
      ("branch", git.branch),
      ("tag", git.tag),
      ("describe", git.describe),
      ("commit", git.commit),
      ("short_commit", git.short_commit),
      ("commit_date", git.commit_date),
      ("author", git.author),
      ("email", git.email),
    ] {
    lines.push(quoted_line(pair.0, @mooninfo.quote(pair.1)))
  }
  lines.push("    dirty: \{git.dirty},")
  lines.push("    ahead: \{git.ahead},")
  lines.push("    behind: \{git.behind},")
  lines.push("  }")
  lines.push("}")
  lines.push("")
  lines.push("///|")
  lines.push("/// Toolchain versions captured when the generator ran.")
  lines.push("pub fn toolchain_versions() -> (String, String) {")
  lines.push(
    "  (\{@mooninfo.quote(toolchain_versions.0)}, \{@mooninfo.quote(toolchain_versions.1)})",
  )
  lines.push("}")
  lines.join("\n") + "\n"
}
