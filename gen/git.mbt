///|
/// Run `git args` in `cwd` and return its stdout, or `None` when git is
/// missing or exits non-zero (no repository, no tag, no upstream — all normal).
///
/// `--no-optional-locks` keeps read-only commands from taking `index.lock`,
/// which would otherwise stall a concurrent build or a user's `git commit`.
fn git(cwd : String, args : Array[String]) -> String? {
  run("git", ["--no-optional-locks", "-C", cwd, ..args])
}

///|
/// The checkout at `cwd`, as a `GitInfo`.
///
/// The one question worth asking git separately is whether `cwd` is in a work
/// tree at all, because no number of failed commands can tell "not a
/// repository" from "a repository on a detached HEAD". That decides
/// `available`; every other command is free to answer with nothing.
///
/// `--untracked-files=no` for `status`: the generated file is committed, so
/// counting untracked files would mark every build as dirty.
fn collect_git_info(cwd : String) -> @gitinfo.GitInfo {
  let field = fn(args : Array[String]) {
    match git(cwd, args) {
      Some(out) => out
      None => ""
    }
  }
  let raw : @gitinfo.RawGitInfo = {
    branch: field(["symbolic-ref", "--short", "-q", "HEAD"]),
    tag: field(["describe", "--tags", "--exact-match"]),
    describe: field(["describe", "--tags", "--always"]),
    commit: field(["rev-parse", "HEAD"]),
    short_commit: field(["rev-parse", "--short", "HEAD"]),
    commit_date: field(["log", "-1", "--format=%cI"]),
    author: field(["log", "-1", "--format=%an"]),
    email: field(["log", "-1", "--format=%ae"]),
    status: field(["status", "--porcelain", "--untracked-files=no"]),
    upstream_count: field([
      "rev-list", "--left-right", "--count", "HEAD...@{upstream}",
    ]),
  }
  with_availability(cwd, raw.to_git_info())
}

///|
/// `info` with `available` narrowed to whether `cwd` is inside a work tree.
fn with_availability(cwd : String, info : @gitinfo.GitInfo) -> @gitinfo.GitInfo {
  let available = match git(cwd, ["rev-parse", "--is-inside-work-tree"]) {
    Some(out) => out.trim() == "true"
    None => false
  }
  { ..info, available, }
}
