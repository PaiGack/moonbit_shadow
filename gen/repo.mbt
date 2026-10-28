///|
/// The checkout at `cwd`: asked of `git` first, read out of `.git` only when
/// there is no usable `git` to ask.
///
/// The generator runs on the build machine, which is usually the one place a
/// `git` executable is guaranteed — and a `git` that answers knows about packed
/// objects, shallow clones and `GIT_DIR`, none of which `gitx/gitz/repo` reads.
/// But
/// "usually" is not "always" (a container built from a source tarball, a CI step
/// that copies the work tree and drops the command), so the second half stays.
///
/// Nothing here asks whether the host is native: the answer to "can I start a
/// process" is the attempt itself.
///
/// `gitx/gitcli` returning a value — even an empty one — is the end of the
/// question. It only returns `None` when `git` could not be started, and the
/// empty value it returns when `git` ran and said "not a repository" carries
/// `reason = GitRefused`. Falling back to `.git` in that case used to be the
/// bug: the reader walked the same directory, found nothing, and the build
/// printed one line that contradicted the one before it instead of saying
/// "there is no checkout here, `git_info().available = false`".
async fn collect_git_info(cwd : String) -> @gitinfo.GitInfo {
  let info = match @gitcli.read_repo_info(cwd) {
    Some(info) => info
    None => {
      println(
        "moon_shadow: `git` is not runnable at \{cwd}, reading .git instead",
      )
      @gitinfo.read_repo_info(cwd)
    }
  }
  // One line about a failed read, and it is about `.git`: a `git` that
  // refused already said why on stderr and needs no translation.
  match info.locate {
    @gitinfo.RepoLocate::Ok => ()
    @gitinfo.RepoLocate::Missing =>
      println(
        "moon_shadow: no git checkout at \{cwd}, baking in git_info().available = false",
      )
    @gitinfo.RepoLocate::Unreadable =>
      println(
        "moon_shadow: \{cwd}/.git names a directory that is not there, baking in git_info().available = false",
      )
  }
  @gitinfo.to_git_info(info)
}
