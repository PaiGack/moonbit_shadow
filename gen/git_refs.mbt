///|
/// Where `.git` is and what `HEAD` says. Nothing here is a value the artifact
/// keeps; it exists so the reading code stays short.
struct Repo {
  /// `objects/`, `refs/` and `packed-refs` live here.
  common_dir : String
  /// `HEAD` lives here; differs from `common_dir` in a linked worktree.
  git_dir : String
}

///|
/// `HEAD`, resolved.
enum Head {
  /// A branch (`refs/heads/main`) and the commit it points at.
  Branch(String, String)
  /// A commit id, with no branch naming it.
  Detached(String)
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
      return make_repo(candidate)
    }
    if is_file(candidate) {
      let pointer = read_text(candidate)
      guard pointer.has_prefix("gitdir:") else { return None }
      let target = normalize(join_path(dir, strip_git_whitespace(pointer[7:])))
      guard is_dir(target) else { return None }
      return make_repo(target)
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
fn make_repo(git_dir : String) -> Repo? {
  let mut common_dir = git_dir
  let pointer = join_path(git_dir, "commondir")
  if is_file(pointer) {
    let target = read_text(pointer)
    if !target.is_empty() {
      common_dir = normalize(join_path(git_dir, target))
    }
  }
  Some({ common_dir, git_dir, })
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
    let name = strip_git_whitespace(text[4:])
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
      let next = strip_git_whitespace(loose[4:])
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
/// `(commit, ref name)` for every entry of `packed-refs`.
fn Repo::packed_ref_entries(self : Repo) -> Array[(String, String)] {
  let entries : Array[(String, String)] = []
  let packed = read_text(join_path(self.common_dir, "packed-refs"))
  for line in packed.split("\n") {
    let entry = strip_git_whitespace(line)
    // `# pack-refs with: peeled fully-peeled` and `^<peeled>` lines carry no
    // ref of their own.
    if entry.is_empty() || entry.has_prefix("#") || entry.has_prefix("^") {
      continue
    }
    match entry.rev_find(" ") {
      Some(index) =>
        entries.push((entry[:index].to_owned(), entry[index + 1:].to_owned()))
      None => ()
    }
  }
  entries
}

///|
/// Every tag pointing at `commit`, sorted by name: two tags on one commit are
/// equally exact, and the generated file may not shuffle between builds.
///
/// An annotated tag names a tag object rather than the commit, and peeling it
/// means reading that object; such a tag is left out instead of guessed at.
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
/// The fields `HEAD` and the refs answer — which is everything except the ones
/// that need a commit object, the index, or the commit graph.
fn Head::to_git_info(
  self : Head,
  repo : Repo,
  cwd : String,
) -> @gitinfo.GitInfo {
  let (branch, commit) = match self {
    Branch(name, commit) => (short_branch(name), commit)
    Detached(commit) => ("", commit)
  }
  let tags = repo.tags_at(commit)
  let tag = if tags.length() > 0 { tags[0] } else { "" }
  let (commit_date, author, email) = read_commit_lines(cwd, commit)
  {
    available: true,
    branch,
    tag,
    // `describe --tags --always`: the exact tag, else `short_commit`. The
    // `-N-g<sha>` form needs the tags reachable from `HEAD` and a count of
    // commits in between, which is the moment this stops being "read a few
    // files".
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
    // Comparing the index against the work tree is a `stat` per file, and
    // `generated.mbt` itself is committed: guessing here marks every build
    // dirty, so the honest answer is "not checked".
    dirty: false,
    // The commit graph, for the same reason.
    ahead: 0,
    behind: 0,
  }
}

///|
/// `(commit_date, author, email)`, from git when it is there.
///
/// The commit object is zlib, and inflating it is a dependency this generator
/// does not take; `git log -1` is the one command left. `%x00` between fields
/// because a US separator can appear in an author name and NUL cannot.
///
/// `None` from `spawn` is a machine without a shell — the fields stay empty
/// rather than the build failing.
fn read_commit_lines(cwd : String, commit : String) -> (String, String, String) {
  let args = [
    "--no-optional-locks", "-C", cwd, "log", "-1", "--format=%cI%x00%an%x00%ae",
    commit,
  ]
  let raw = match spawn("git", args) {
    Some((stdout, code)) => if code == "0" { stdout } else { "" }
    None => ""
  }
  @gitinfo.parse_commit_lines(raw)
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
