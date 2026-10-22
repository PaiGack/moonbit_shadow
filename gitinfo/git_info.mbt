///|
/// A snapshot of the git repository that was checked out when this module was
/// built, rendered into the artifact at build time.
///
/// Filled in by `gen`, never by the running program: the machine that runs the
/// software has no `.git`, may not have `git`, and its cwd is none of your
/// business.
pub(all) struct GitInfo {
  /// `false` when the build happened outside a git repository, or without
  /// `git` installed. Every other field is then empty / zero.
  available : Bool
  /// `symbolic-ref --short HEAD`; empty on a detached HEAD.
  branch : String
  /// `describe --tags --exact-match`; empty when HEAD is not a tag.
  tag : String
  /// `describe --tags --always`, a stable name for any commit.
  describe : String
  commit : String
  short_commit : String
  /// ISO 8601, in the committer's timezone.
  commit_date : String
  author : String
  email : String
  /// Tracked files with uncommitted changes. Untracked files do not count:
  /// `generated.mbt` is committed, so counting them would report every build
  /// as dirty.
  dirty : Bool
  /// Commits ahead of / behind the upstream branch; both 0 without one.
  ahead : Int32
  behind : Int32
} derive(Eq, Debug)

///|
#deprecated
pub extend GitInfo with Eq::{not_equal, equal}

///|
#deprecated
pub extend GitInfo with Debug::{to_repr}

///|
/// The "no git here" value: `available = false`, everything else empty.
pub fn GitInfo::none() -> GitInfo {
  {
    available: false,
    branch: "",
    tag: "",
    describe: "",
    commit: "",
    short_commit: "",
    commit_date: "",
    author: "",
    email: "",
    dirty: false,
    ahead: 0,
    behind: 0,
  }
}

///|
/// Whether the value carries a commit worth printing.
pub fn GitInfo::is_dirty(self : GitInfo) -> Bool {
  self.available && self.dirty
}

///|
/// `name[-dirty]`: the branch name, the tag, or the describe output, whichever
/// is the most specific thing known about HEAD.
pub fn GitInfo::describe_version(self : GitInfo) -> String {
  let name = if !self.tag.is_empty() {
    self.tag
  } else if !self.branch.is_empty() {
    self.branch
  } else {
    self.describe
  }
  if self.is_dirty() {
    "\{name}-dirty"
  } else {
    name
  }
}

///|
/// `<commit>[-dirty]`, or the short form when `short` is set.
pub fn GitInfo::commit_version(self : GitInfo, short~ : Bool = false) -> String {
  let commit = if short { self.short_commit } else { self.commit }
  if self.is_dirty() {
    "\{commit}-dirty"
  } else {
    commit
  }
}

///|
/// `available=false` becomes `unavailable` instead of an empty string, so a
/// `--version` line does not end in dangling separators.
pub fn GitInfo::to_version_string(self : GitInfo) -> String {
  if !self.available {
    return "unavailable"
  }
  let parts : Array[String] = []
  for part in [self.describe_version(), self.commit_version(short=true)] {
    if !part.is_empty() {
      parts.push(part)
    }
  }
  parts.join(" ")
}
