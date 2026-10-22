///|
/// Run a git command in `cwd` and return its stdout, or `None` when git is
/// missing, or exits non-zero (no repository, no tag, no upstream — all normal).
///
/// `GIT_OPTIONAL_LOCKS=0` keeps read-only commands from taking `index.lock`,
/// which would otherwise stall a concurrent build or a user's `git commit`.
fn git(cwd : String, args : Array[String]) -> String? {
  let status = @process.run("git", args, cwd~, env={
    "GIT_OPTIONAL_LOCKS": "0",
    "LC_ALL": "C",
  }) catch {
    _ => return None
  }
  guard status.code == 0 else { return None }
  Some(status.stdout)
}

///|
/// Whether `cwd` sits in a work tree at all. Every command below is allowed to
/// fail; this one decides between "no git here" and "a repository with no tag".
fn git_available(cwd : String) -> Bool {
  match git(cwd, ["rev-parse", "--is-inside-work-tree"]) {
    Some(out) => out.trim().contains("true")
    None => false
  }
}

///|
/// Collect the raw field values.
///
/// `--untracked-files=no` for `status`: the generated file is committed, so
/// counting untracked files would mark every build as dirty.
fn RawGitInfo::collect(cwd : String) -> @gitinfo.RawGitInfo {
  let field = fn(args : Array[String]) {
    match git(cwd, args) {
      Some(out) => out
      None => ""
    }
  }
  {
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
}
