///|
/// The checkout at `cwd`, read straight out of the files `git` would read.
///
/// The generator is a build tool that has to run wherever `moon` runs, and
/// spawning a process is the least portable thing it could do. `HEAD`, the ref
/// it names, `packed-refs` and `refs/tags/*` are plain files; that is what git
/// reads too.
///
/// `locate` comes back beside the value because it is the one thing worth
/// printing: "no repository" and "a `.git` that points nowhere" are different
/// mistakes, and `GitInfo` is baked into the artifact, not logged.
fn collect_git_info(cwd : String) -> (@gitinfo.GitInfo, @gitinfo.RepoLocate) {
  let repo = match discover(cwd) {
    Some(repo) => repo
    None => return (@gitinfo.GitInfo::none(), @gitinfo.RepoLocate::Missing)
  }
  // A `HEAD` that names nothing is a half-written clone. Its refs are stale by
  // definition, and a stale version number is worse than none.
  let head = match repo.read_head() {
    Some(head) => head
    None => return (@gitinfo.GitInfo::none(), @gitinfo.RepoLocate::Unreadable)
  }
  (head.to_git_info(repo, cwd), @gitinfo.RepoLocate::Ok)
}
