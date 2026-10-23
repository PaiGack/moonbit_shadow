///|
/// A checkout read straight out of `.git`, before it is narrowed to a
/// `GitInfo`.
///
/// Everything here is a file's contents, produced by `gen` and understood by
/// this package: the generator knows where a ref lives, this side knows what a
/// ref means. `locate` matters because `.git` is a *file* in a worktree and in
/// a submodule, and a reader that walks into one and gives up looks exactly
/// like "no repository here".
pub(all) struct RepoInfo {
  available : Bool
  locate : RepoLocate
  branch : String
  tag : String
  describe : String
  commit : String
  short_commit : String
  commit_date : String
  author : String
  email : String
  dirty : Bool
  ahead : Int32
  behind : Int32
} derive(Eq, Debug)

///|
#deprecated
pub extend RepoInfo with Eq::{not_equal, equal}

///|
#deprecated
pub extend RepoInfo with Debug::{to_repr}

///|
/// What the reader did with `.git`.
pub(all) enum RepoLocate {
  /// Found it, and it is a work tree.
  Ok
  /// No `.git` on the way up.
  Missing
  /// `.git` is a file naming a directory that is not there — a worktree left
  /// behind by a checkout that has been pruned.
  Unreadable
} derive(Eq, Debug)

///|
#deprecated
pub extend RepoLocate with Eq::{not_equal, equal}

///|
#deprecated
pub extend RepoLocate with Debug::{to_repr}

///|
/// The "nothing here" value.
pub fn RepoInfo::empty() -> RepoInfo {
  {
    available: false,
    locate: Missing,
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
/// The fields of `GitInfo` a `.git` reader can answer.
///
/// `commit_date` / `author` / `email` need the commit object, `dirty` needs the
/// index and a `stat` per file, and `ahead` / `behind` need the commit graph.
/// All four are left empty rather than guessed: `gitinfo` does not invent a
/// date to fill a hole.
pub fn RepoInfo::to_git_info(self : RepoInfo) -> GitInfo {
  let available = self.available && self.locate is Ok
  {
    available,
    branch: trim(self.branch),
    tag: trim(self.tag),
    describe: trim(self.describe),
    commit: trim(self.commit),
    short_commit: trim(self.short_commit),
    commit_date: trim(self.commit_date),
    author: trim(self.author),
    email: trim(self.email),
    dirty: available && self.dirty,
    ahead: if available {
      self.ahead
    } else {
      0
    },
    behind: if available {
      self.behind
    } else {
      0
    },
  }
}
