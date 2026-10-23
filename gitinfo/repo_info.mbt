///|
/// The `.git` reader, re-exported: reading a checkout is `gitx/gitz/repo`'s
/// job, but the value it produces is part of *this* package's surface.
pub using @repo {type Checkout, type RepoInfo, type RepoLocate}

///|
/// The checkout at `cwd`, read out of the files `git` itself would read.
///
/// The other half of the pair is `gitx/gitcli`, which asks a `git` executable;
/// this one opens `HEAD`, refs, `packed-refs`, the commit object and the index.
/// `moon.mod` is not involved: this is a directory in.
pub fn read_repo_info(cwd : String) -> RepoInfo {
  @repo.read_checkout(cwd).to_repo_info()
}

///|
/// Whitespace off both ends, everything else kept. A ref file written by git
/// ends in a newline, and a version string may not.
fn trim(text : String) -> String {
  let chars = text.to_array()
  let mut end = chars.length()
  while end > 0 && is_space(chars[end - 1]) {
    end = end - 1
  }
  let mut start = 0
  while start < end && is_space(chars[start]) {
    start = start + 1
  }
  let out = StringBuilder()
  for i in start..<end {
    out.write_char(chars[i])
  }
  out.to_string()
}

///|
fn is_space(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}

///|
/// The fields of `GitInfo` a `.git` reader can answer.
///
/// `commit_date` / `author` / `email` need the commit object, `dirty` needs the
/// index and a `stat` per file, and `ahead` / `behind` need the commit graph.
/// All four are left empty rather than guessed: `gitinfo` does not invent a
/// date to fill a hole.
pub fn to_git_info(info : RepoInfo) -> GitInfo {
  let available = info.available && info.locate is Ok
  {
    available,
    branch: trim(info.branch),
    tag: trim(info.tag),
    describe: trim(info.describe),
    commit: trim(info.commit),
    short_commit: trim(info.short_commit),
    commit_date: trim(info.commit_date),
    author: trim(info.author),
    email: trim(info.email),
    dirty: available && info.dirty,
    ahead: if available {
      info.ahead
    } else {
      0
    },
    behind: if available {
      info.behind
    } else {
      0
    },
  }
}
