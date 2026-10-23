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
/// is answered by trying it. `None` means "no usable `git`", and every failure
/// along the way — not installed, not a repository, an unreadable work tree —
/// is that same answer, because the caller's next move is the same for all of
/// them.
pub async fn read_repo_info(cwd : String) -> @gitinfo.RepoInfo? {
  // The one call that decides whether there is a `git` to talk to at all.
  // Everything after it either has an answer or a default.
  let root = git(["rev-parse", "--show-toplevel"], cwd) catch {
    _ => return None
  }
  guard !root.is_empty() else { return None }
  let commit = git(["rev-parse", "HEAD"], cwd) catch { _ => return None }
  guard is_hex(commit) else { return None }
  // A bare repository has no work tree, so there is no "dirty" to report and
  // no branch to be on. `gitx/gitz/repo` would say the same: the index comparison
  // needs a work tree.
  let is_bare = git(["rev-parse", "--is-bare-repository"], cwd) catch {
    _ => ""
  }
  let bare = is_bare == "true"
  // Author, e-mail, ISO date, decoration — in that order, so the decoration
  // comes last and can hold anything.
  // `%x09` rather than a literal tab keeps the format string printable, and
  // `--no-show-signature` keeps a signed commit's gpg noise out of the line.
  let fields = git(
    [
      "log", "-1", "--no-show-signature", "--date=iso-strict", "--format=%an%x09%ae%x09%cI%x09%D",
    ],
    cwd,
  ) catch {
    _ => return None
  }
  let parsed = split_fields(fields)
  let (ahead, behind) = track_counts(
    git(["rev-list", "--left-right", "--count", "HEAD...@{upstream}"], cwd) catch {
      _ => ""
    },
  )
  // `git describe` fails on a repository with no commit at all and shortens a
  // shallow one. Both are answers, so the fallback is the commit id the file reader
  // would also settle on.
  let described = git(["describe", "--tags", "--always"], cwd) catch { _ => "" }
  let short_commit = git(["rev-parse", "--short", "HEAD"], cwd) catch {
    _ => short_of(commit)
  }
  let info : @gitinfo.RepoInfo = {
    available: true,
    locate: @gitinfo.RepoLocate::Ok,
    // Fails on a detached HEAD, which is exactly when there is no branch.
    branch: if bare {
      ""
    } else {
      git(["symbolic-ref", "--short", "-q", "HEAD"], cwd) catch {
        _ => ""
      }
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
  let status = git(["status", "--porcelain", "--untracked-files=no"], cwd) catch {
    _ => ""
  }
  status.length() > 0
}

///|
/// `git <args>` in `cwd`, trimmed. Whatever came back is a value: a non-zero
/// exit is a `raise`, so callers only deal with the text they asked for.
async fn git(args : Array[String], cwd : String) -> String {
  let (status, stdout) = @process.collect_stdout(
    "git",
    args,
    cwd~,
    no_console_window=true,
  )
  if status != 0 {
    raise Failure("git \{args.join(" ")} exited with \{status}")
  }
  stdout.text()
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
