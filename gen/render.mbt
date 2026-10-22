///|
/// Same escaping rules as `core`: the values are re-emitted as MoonBit source.
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
/// The whole implementation file: `module_info()` from `core`, plus
/// `git_info()`, which only `gen` knows how to shape.
///
/// Deterministic by construction — no timestamp, no random — so regenerating
/// from the same inputs yields no diff, and a committed `generated.mbt` never
/// makes the work tree dirty behind the user's back.
fn render(git : @gitinfo.GitInfo, module_block : String) -> String {
  let lines : Array[String] = [module_block]
  lines.push("///|")
  lines.push("/// Generated from the git checkout this module was built in.")
  lines.push("pub fn git_info() -> @gitinfo.GitInfo {")
  lines.push("  {")
  lines.push("    available: \{git.available},")
  lines.push("    branch: \{quote(git.branch)},")
  lines.push("    tag: \{quote(git.tag)},")
  lines.push("    describe: \{quote(git.describe)},")
  lines.push("    commit: \{quote(git.commit)},")
  lines.push("    short_commit: \{quote(git.short_commit)},")
  lines.push("    commit_date: \{quote(git.commit_date)},")
  lines.push("    author: \{quote(git.author)},")
  lines.push("    email: \{quote(git.email)},")
  lines.push("    dirty: \{git.dirty},")
  lines.push("    ahead: \{git.ahead},")
  lines.push("    behind: \{git.behind},")
  lines.push("  }")
  lines.push("}")
  lines.join("\n") + "\n"
}
