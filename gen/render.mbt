///|
/// The whole implementation file: `module_info()` from `mooninfo` and
/// `build_info()` from `buildinfo`, plus `git_info()`, whose shape only `gen`
/// knows.
///
/// Deterministic by construction — no timestamp, no random — so regenerating
/// from the same inputs yields no diff, and a committed `generated.mbt` never
/// makes the work tree dirty behind the user's back.
///
/// `git_path`, `buildinfo_path` and `mooninfo`'s own path are the full package
/// paths of the types the accessors return. A virtual implementation's
/// `pkg.mbti` is written by hand, so the generated file spells them the same
/// way it does; a full path works no matter what aliases the implementation
/// package happens to declare.
fn quoted_line(name : String, quoted : String) -> String {
  "    \{name}: \{quoted},"
}

///|
fn render(
  git : @gitinfo.GitInfo,
  module_block : String,
  toolchain : @buildinfo.ToolchainInfo,
  git_path~ : String,
  buildinfo_path~ : String,
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
  lines.push(@buildinfo.render_build_info(toolchain, pkg_path=buildinfo_path))
  lines.join("\n") + "\n"
}
