///|
/// The checkout at `cwd`, asked of `git` itself.
///
/// The other half of `gitx/gitz/repo`: that package opens `.git` and reads the
/// files, this one runs the command. Neither is enough alone — a reader knows nothing
/// about packed objects, shallow clones or `GIT_DIR`, and a `git` that is not
/// installed cannot be asked anything — so `gen` tries this first and keeps
/// the file reader for the machines where the command is missing.
///
/// Nothing here inspects the platform: whether a process can be started at all
/// is answered by trying it. `None` means "no usable `git`" — and that is only
/// said when the command could not be *started*. A `git` that ran and refused
/// (exit 128, `fatal: not a git repository`) is an answer, and it comes back as
/// `available = false` with `reason = GitRefused`, so the caller does not go
/// on to read `.git` and contradict it.
///
/// The exit code is read, not raised: a raised error used to skip everything
/// below it, and the `git status` at the end of a successful read never ran.
pub async fn read_repo_info(cwd : String) -> @gitinfo.RepoInfo? {
  // The one call that decides whether there is a `git` to talk to at all.
  // Everything after it either has an answer or a default.
  let (status, stdout) = match
    run(["rev-parse", "--show-toplevel", "--git-dir"], cwd) {
    Some(output) => output
    None => return None
  }
  // Not a repository, a bare repository, a work tree git cannot enter: git
  // says why on stderr and exits non-zero, and there is nothing to report as
  // metadata. `--git-dir` rides along so the bare case is one call, not two.
  guard status == 0 else {
    return Some(@gitinfo.RepoInfo::empty(reason=GitRefused))
  }
  let lines = non_empty_lines(stdout)
  guard lines.length() >= 1 && !lines[0].is_empty() else {
    return Some(@gitinfo.RepoInfo::empty(reason=GitRefused))
  }
  let commit = match git(["rev-parse", "HEAD"], cwd) {
    Some(output) => output
    None => return Some(@gitinfo.RepoInfo::empty(reason=GitRefused))
  }
  // `git init` followed by nothing has a `HEAD` and no commit: an answer, with
  // no commit worth printing.
  guard is_hex(commit) else {
    return Some(@gitinfo.RepoInfo::empty(reason=GitRefused))
  }
  // A bare repository has no work tree, so there is no "dirty" to report and
  // no branch to be on. `gitx/gitz/repo` would say the same: the index comparison
  // needs a work tree.
  let bare = lines.length() >= 2 &&
    (trim(lines[1]).has_prefix(".git") || trim(lines[1]) == "")
  // Author, e-mail, ISO date, decoration — in that order, so the decoration
  // comes last and can hold anything.
  // `%x09` rather than a literal tab keeps the format string printable, and
  // `--no-show-signature` keeps a signed commit's gpg noise out of the line.
  let fields = match
    git(
      [
        "log", "-1", "--no-show-signature", "--date=iso-strict", "--format=%an%x09%ae%x09%cI%x09%D",
      ],
      cwd,
    ) {
    Some(output) => output
    None => ""
  }
  let parsed = split_fields(fields)
  let (ahead, behind) = track_counts(
    opt(git(["rev-list", "--left-right", "--count", "HEAD...@{upstream}"], cwd)),
  )
  // `git describe` fails on a repository with no commit at all and shortens a
  // shallow one. Both are answers, so the fallback is the commit id the file reader
  // would also settle on.
  let described = opt(git(["describe", "--tags", "--always"], cwd))
  let short_commit = opt(git(["rev-parse", "--short", "HEAD"], cwd))
  let short_commit = if short_commit.is_empty() {
    short_of(commit)
  } else {
    short_commit
  }
  let info : @gitinfo.RepoInfo = {
    available: true,
    locate: @gitinfo.RepoLocate::Ok,
    reason: @gitinfo.CheckoutReason::Found,
    // Fails on a detached HEAD, which is exactly when there is no branch.
    branch: if bare {
      ""
    } else {
      opt(git(["symbolic-ref", "--short", "-q", "HEAD"], cwd))
    },
    tag: tag_of(parsed[3]),
    describe: if described.is_empty() {
      short_of(commit)
    } else {
      described
    },
    commit,
    short_commit,
    commit_date: parsed[2],
    author: parsed[0],
    email: parsed[1],
    // Tracked files only: the generator's own output is a tracked file, and a
    // rule that marked every build dirty would never stop rewriting itself.
    dirty: if bare {
      false
    } else {
      dirty(cwd)
    },
    ahead,
    behind,
  }
  Some(info)
}

///|
/// Whether tracked files differ from `HEAD`. `git status` that fails is read as
/// "clean": a version string is not worth failing a build over.
async fn dirty(cwd : String) -> Bool {
  match run(["status", "--porcelain", "--untracked-files=no"], cwd) {
    Some((0, stdout)) => trim(stdout).length() > 0
    // A `git status` that failed is read as "clean", as before: a version
    // string is not worth failing a build over.
    _ => false
  }
}

///|
/// `git <args>` in `cwd`, trimmed, or `None` when it exited non-zero.
///
/// The exit code comes back beside the text instead of in place of it:
/// `rev-parse --show-toplevel --git-dir` answers with two lines on success and
/// with `fatal: not a git repository` on failure, and which of the two it was
/// is the whole question the caller is asking.
async fn git(args : Array[String], cwd : String) -> String? {
  match run(args, cwd) {
    Some((0, stdout)) => Some(trim(stdout))
    _ => None
  }
}

///|
fn opt(value : String?) -> String {
  match value {
    Some(text) => text
    None => ""
  }
}

///|
/// `git <args>` in `cwd`: the exit code and whatever it printed on stdout.
///
/// `None` when the process could not be started at all — no `git` on `PATH`,
/// no such `cwd`. That is the only kind of failure this function raises about
/// on the caller's behalf: a git that ran and refused is `Some((128, ""))`,
/// because the caller's next move is different from "no git here".
async fn run(args : Array[String], cwd : String) -> (Int32, String)? {
  let output = @process.collect_output(
    "git",
    args,
    cwd~,
    no_console_window=true,
  ) catch {
    _ => return None
  }
  let (status, stdout, _stderr) = output
  Some((status, stdout.text()))
}

///|
/// `git` output as lines, blank ones dropped: `rev-parse` prints one line per
/// argument and the list is read by position.
fn non_empty_lines(text : String) -> Array[String] {
  let lines : Array[String] = []
  for line in text.split("\n") {
    let entry = trim(line)
    if !entry.is_empty() {
      lines.push(entry)
    }
  }
  lines
}

///|
/// `%an%x09%ae%x09%cI%x09%D` split back apart.
///
/// Fixed arity: an author name may hold a tab and the decoration is text, so
/// only the first three separators are trusted, which is what `splitn` in
/// other languages would give.
fn split_fields(line : String) -> Array[String] {
  let fields : Array[String] = []
  let mut rest = line
  for _ in 0..<3 {
    match rest.find("\t") {
      Some(index) => {
        fields.push(trim(rest[:index]))
        rest = rest[index + 1:].to_owned()
      }
      None => {
        fields.push(trim(rest))
        rest = ""
        break
      }
    }
  }
  fields.push(trim(rest))
  while fields.length() < 4 {
    fields.push("")
  }
  fields
}

///|
/// `%D` -> the tag pointing at HEAD, if any.
///
/// `HEAD -> main, tag: v1.0.0, origin/main`. A decorated tag is `tag: <name>`.
/// Annotated and lightweight tags both show up here, and neither is preferred
/// over the other: they name the same commit.
fn tag_of(decorated : String) -> String {
  for part in decorated.split(",") {
    let entry = trim(part)
    let prefix = "tag: "
    if entry.has_prefix(prefix) {
      return entry[prefix.length():].to_owned()
    }
  }
  ""
}

///|
fn short_of(commit : String) -> String {
  if commit.length() > 7 {
    commit[:7].to_owned()
  } else {
    commit
  }
}

///|
/// `<ahead>\t<behind>` from `rev-list --left-right --count`.
///
/// Empty output is the normal answer for a branch with no upstream: git exits
/// zero there and prints nothing, so 0/0 is not an error.
fn track_counts(output : String) -> (Int32, Int32) {
  let fields = split_fields(output)
  (int_or_zero(fields[0]), int_or_zero(fields[1]))
}

///|
fn int_or_zero(text : String) -> Int32 {
  // Digits only: `git rev-list --count` never prints a sign, and a value past
  // `Int32` would be a history nobody needs a version string from.
  let mut value = 0
  for ch in text {
    guard ch >= '0' && ch <= '9' else { return 0 }
    value = value * 10 + (ch.to_int() - '0'.to_int())
    guard value <= 2147483647 else { return 0 }
  }
  value
}

///|
fn is_hex(text : String) -> Bool {
  if text.length() < 40 {
    return false
  }
  for i in 0..<40 {
    let ch = text[i]
    guard (ch >= '0' && ch <= '9') ||
      (ch >= 'a' && ch <= 'f') ||
      (ch >= 'A' && ch <= 'F') else {
      return false
    }
  }
  true
}

///|
fn is_whitespace(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}

///|
fn trim(text : StringView) -> String {
  let chars = text.to_array()
  let mut end = chars.length()
  while end > 0 && is_whitespace(chars[end - 1]) {
    end = end - 1
  }
  let mut start = 0
  while start < end && is_whitespace(chars[start]) {
    start = start + 1
  }
  let buf = StringBuilder()
  for i in start..<end {
    buf.write_char(chars[i])
  }
  buf.to_string()
}
