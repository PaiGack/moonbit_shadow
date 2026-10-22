///|
/// Raw output of the git commands, as `gen` captured them.
///
/// Split from `GitInfo` so the "what does this string mean" part can be tested
/// without a git repository: `gen` runs the commands, `gitinfo` only reads.
pub(all) struct RawGitInfo {
  branch : String
  tag : String
  describe : String
  commit : String
  short_commit : String
  commit_date : String
  author : String
  email : String
  /// `status --porcelain --untracked-files=no`: empty means clean.
  status : String
  /// `rev-list --left-right --count HEAD...@{upstream}`, `<ahead>\t<behind>`.
  /// Empty when there is no upstream.
  upstream_count : String
}

///|
pub fn RawGitInfo::empty() -> RawGitInfo {
  {
    branch: "",
    tag: "",
    describe: "",
    commit: "",
    short_commit: "",
    commit_date: "",
    author: "",
    email: "",
    status: "",
    upstream_count: "",
  }
}

///|
/// Whitespace off both ends, everything else kept: author names may contain
/// spaces, and an empty output is normal (no tag, no upstream).
///
/// Takes a `StringView` so `split` results do not have to be copied first.
fn trim(s : StringView) -> String {
  let chars = s.to_array()
  let mut end = chars.length()
  while end > 0 && is_space_char(chars[end - 1]) {
    end = end - 1
  }
  let mut start = 0
  while start < end && is_space_char(chars[start]) {
    start = start + 1
  }
  let buf = StringBuilder()
  for i in start..<end {
    buf.write_char(chars[i])
  }
  buf.to_string()
}

///|
fn is_space_char(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}

///|
/// A run of ASCII digits, or 0 for anything else — the output comes from git,
/// so a sign or a stray word means "no answer", not a number to salvage.
fn digit_count(field : StringView) -> Int32 {
  if field.is_empty() {
    return 0
  }
  for ch in field {
    guard ch >= '0' && ch <= '9' else { return 0 }
  }
  @string.parse_int(field) catch {
    _ => 0
  }
}

///|
/// Parse `<ahead>\t<behind>`; anything unparsable is `(0, 0)`.
fn parse_counts(raw : String) -> (Int32, Int32) {
  let fields = trim(raw)
    .split("\t")
    .map(fn(part) { trim(part) })
    .filter(fn(part) { !part.is_empty() })
    .collect()
  if fields.length() != 2 {
    return (0, 0)
  }
  (digit_count(fields[0]), digit_count(fields[1]))
}

///|
/// Interpret the captured output. `available` is decided by the caller: only it
/// knows whether git actually ran.
pub fn RawGitInfo::to_git_info(self : RawGitInfo) -> GitInfo {
  let (ahead, behind) = parse_counts(self.upstream_count)
  {
    available: true,
    branch: trim(self.branch),
    tag: trim(self.tag),
    describe: if trim(self.describe).is_empty() {
      // `describe --always` always prints something, but a generator run from
      // a foreign shell could hand us blanks; short_commit is the fallback.
      trim(self.short_commit)
    } else {
      trim(self.describe)
    },
    commit: trim(self.commit),
    short_commit: trim(self.short_commit),
    commit_date: trim(self.commit_date),
    author: trim(self.author),
    email: trim(self.email),
    dirty: !trim(self.status).is_empty(),
    ahead,
    behind,
  }
}
