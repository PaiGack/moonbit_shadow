///|
/// Where `.git` is and what `HEAD` says. Nothing here is a value the artifact
/// keeps; it exists so the reading code stays short.
priv struct Repo {
  /// `objects/`, `refs/` and `packed-refs` live here.
  common_dir : String
  /// `HEAD` lives here; differs from `common_dir` in a linked worktree.
  git_dir : String
  /// The checkout the search started from, for the index and the work tree.
  work_dir : String
}

///|
/// `HEAD`, resolved.
priv enum Head {
  /// A branch (`refs/heads/main`) and the commit it points at.
  Branch(String, String)
  /// A commit id, with no branch naming it.
  Detached(String)
}

///|
/// The checkout at `cwd`, read straight out of the files `git` would read.
///
/// This is the whole point of the library: the machine that runs the software
/// has no `.git` and maybe no `git`, and the build machine should not need a
/// shell either. `HEAD`, the ref it names, `packed-refs`, `refs/tags/*`, the
/// commit object and the index are all plain files — that is what git reads
/// too.
///
/// `locate` comes back beside the value because it is the one thing worth
/// printing: "no repository" and "a `.git` that points nowhere" are different
/// mistakes, and `GitInfo` is baked into the artifact, not logged.
pub fn read_repo_info(cwd : String) -> RepoInfo {
  let repo = match discover(cwd) {
    Some(repo) => repo
    None => return RepoInfo::empty()
  }
  // A `HEAD` that names nothing is a half-written clone. Its refs are stale by
  // definition, and a stale version number is worse than none.
  let head = match repo.read_head() {
    Some(head) => head
    None => return { ..RepoInfo::empty(), locate: Unreadable, }
  }
  head.to_repo_info(repo)
}

///|
/// Walk up from `cwd` to the first `.git`, the way git does.
///
/// Two shapes to handle: `<dir>/.git` as a directory, and `<dir>/.git` as a
/// file holding `gitdir: <path>` — a linked worktree (`<common>/.git/worktrees/
/// <name>`, which has a `commondir` file pointing back) or a submodule
/// (`.git/modules/<name>`, which has none).
fn discover(cwd : String) -> Repo? {
  let mut dir = normalize(cwd)
  while true {
    let candidate = join_path(dir, ".git")
    if is_dir(candidate) {
      return make_repo(candidate, dir)
    }
    if is_file(candidate) {
      let pointer = read_text(candidate)
      guard pointer.has_prefix("gitdir:") else { return None }
      let target = normalize(join_path(dir, trim(pointer[7:])))
      guard is_dir(target) else { return None }
      return make_repo(target, dir)
    }
    let up = normalize(join_path(dir, ".."))
    if up == dir {
      break None
    }
    dir = up
  } nobreak {
    None
  }
}

///|
fn make_repo(git_dir : String, work_dir : String) -> Repo? {
  let mut common_dir = git_dir
  let pointer = join_path(git_dir, "commondir")
  if is_file(pointer) {
    let target = read_text(pointer)
    if !target.is_empty() {
      common_dir = normalize(join_path(git_dir, target))
    }
  }
  Some({ common_dir, git_dir, work_dir, })
}

///|
/// `HEAD` as a commit, and the ref that named it.
///
/// A symbolic `HEAD` is followed by hand: a repository fresh out of `git init`,
/// or a worktree that has not checked anything out, has `HEAD` naming a branch
/// whose file does not exist yet. That is a normal state, not an error.
fn Repo::read_head(self : Repo) -> Head? {
  let text = read_text(join_path(self.git_dir, "HEAD"))
  self.resolve_ref_text(text, depth=0)
}

///|
fn Repo::resolve_ref_text(self : Repo, text : String, depth~ : Int32) -> Head? {
  guard depth < 5 else { return None }
  if text.has_prefix("ref:") {
    let name = trim(text[4:])
    guard !name.is_empty() else { return None }
    let commit = self.read_ref(name, depth)
    guard !commit.is_empty() else { return None }
    return Some(Branch(name, commit))
  }
  // Anything else that is not an object id is a `HEAD` this reader cannot use.
  if text.length() >= 40 && is_hex(text[:40]) {
    return Some(Detached(text))
  }
  None
}

///|
/// One ref: the loose file first, then `packed-refs`.
///
/// A ref that exists in both places is the loose one: `git pack-refs` deletes
/// the loose file when it packs, so the two agree, and an edit leaves the newer
/// value loose.
fn Repo::read_ref(self : Repo, name : String, depth : Int32) -> String {
  let loose = read_text(join_path(self.common_dir, name))
  if !loose.is_empty() {
    // A ref file never holds `ref:`, but a broken one holding it is better
    // followed than returned as if it were a commit id.
    if loose.has_prefix("ref:") {
      let next = trim(loose[4:])
      guard depth < 5 && !next.is_empty() else { return "" }
      return self.read_ref(next, depth + 1)
    }
    return loose
  }
  self.read_packed_ref(name)
}

///|
fn Repo::read_packed_ref(self : Repo, name : String) -> String {
  for entry in self.packed_ref_entries() {
    if entry.1 == name {
      return entry.0
    }
  }
  ""
}

///|
/// `(commit, ref name)` for every entry of `packed-refs`, peeled tags
/// included: `^<commit>` belongs to the entry above it, which is how an
/// annotated tag comes to name a commit without the tag object being read.
fn Repo::packed_ref_entries(self : Repo) -> Array[(String, String)] {
  let entries : Array[(String, String)] = []
  let packed = read_text(join_path(self.common_dir, "packed-refs"))
  let mut last = -1
  for line in packed.split("\n") {
    let entry = trim(line)
    // `# pack-refs with: peeled fully-peeled` carries no ref of its own.
    if entry.is_empty() || entry.has_prefix("#") {
      continue
    }
    if entry.has_prefix("^") {
      guard last >= 0 else { continue }
      let (commit, name) = entries[last]
      let _ = (commit, name)
      entries[last] = (entry[1:].to_owned(), name)
      continue
    }
    match entry.rev_find(" ") {
      Some(index) => {
        entries.push((entry[:index].to_owned(), entry[index + 1:].to_owned()))
        last = entries.length() - 1
      }
      None => ()
    }
  }
  entries
}

///|
/// Every tag pointing at `commit`, sorted by name: two tags on one commit are
/// equally exact, and the generated file may not shuffle between builds.
fn Repo::tags_at(self : Repo, commit : String) -> Array[String] {
  let names : Array[String] = []
  for name in self.list_refs("refs/tags") {
    if self.read_ref(name, 0) == commit {
      // `refs/tags/v1.0.0` -> `v1.0.0`.
      names.push(name[10:].to_owned())
    }
  }
  names.sort()
  names
}

///|
/// Ref names below `prefix`, from `refs/` and from `packed-refs`.
fn Repo::list_refs(self : Repo, prefix : String) -> Array[String] {
  let names : Array[String] = []
  walk_refs(join_path(self.common_dir, prefix), prefix, names)
  for entry in self.packed_ref_entries() {
    let name = entry.1
    if name.has_prefix(prefix + "/") && !names.contains(name) {
      names.push(name)
    }
  }
  names
}

///|
/// `dir` as a ref prefix. A ref is a file at the end of a path, so directories
/// are walked recursively; `.git/refs` is small enough for that to cost
/// nothing.
fn walk_refs(dir : String, prefix : String, names : Array[String]) -> Unit {
  let entries = @fs.read_dir(dir) catch { _ => return }
  for entry in entries {
    let path = join_path(dir, entry)
    let name = prefix + "/" + entry
    if is_dir(path) {
      walk_refs(path, name, names)
    } else if is_file(path) {
      names.push(name)
    }
  }
}

///|
fn Head::to_repo_info(self : Head, repo : Repo) -> RepoInfo {
  let (branch, commit) = match self {
    Branch(name, commit) => (short_branch(name), commit)
    Detached(commit) => ("", commit)
  }
  let tag = match repo.tags_at(commit) {
    [] => ""
    tags => tags[0]
  }
  let commit_object = repo.read_commit(commit)
  let (commit_date, author, email) = match commit_object {
    Some(object) => (object.date, object.author, object.email)
    None => ("", "", "")
  }
  let (ahead, behind) = match commit_object {
    Some(object) => repo.tracking(branch, object)
    None => (0, 0)
  }
  {
    available: true,
    locate: Ok,
    branch,
    tag,
    describe: if !tag.is_empty() {
      tag
    } else {
      short_id(commit)
    },
    commit,
    short_commit: short_id(commit),
    commit_date,
    author,
    email,
    dirty: repo.is_dirty(),
    ahead,
    behind,
  }
}

///|
/// `refs/heads/main` -> `main`.
fn short_branch(name : String) -> String {
  let prefix = "refs/heads/"
  if name.has_prefix(prefix) {
    name[prefix.length():].to_owned()
  } else {
    name
  }
}

///|
fn short_id(commit : String) -> String {
  if commit.length() > 7 {
    commit[:7].to_owned()
  } else {
    commit
  }
}

///|
fn is_hex(text : StringView) -> Bool {
  for ch in text {
    let ok = (ch >= '0' && ch <= '9') ||
      (ch >= 'a' && ch <= 'f') ||
      (ch >= 'A' && ch <= 'F')
    guard ok else { return false }
  }
  true
}
