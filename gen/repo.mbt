///|
/// The checkout at `cwd`: asked of `git` first, read out of `.git` only when
/// there is no usable `git` to ask.
///
/// The generator runs on the build machine, which is usually the one place a
/// `git` executable is guaranteed — and a `git` that answers knows about packed
/// objects, shallow clones and `GIT_DIR`, none of which `gitinfo` reads. But
/// "usually" is not "always" (a container built from a source tarball, a CI step
/// that copies the work tree and drops the command), so the second half stays.
///
/// Nothing here asks whether the host is native: the answer to "can I start a
/// process" is the attempt itself.
async fn collect_git_info(cwd : String) -> @gitinfo.GitInfo {
  let info = match @gitcli.read_repo_info(cwd) {
    Some(info) => info
    None => {
      println(
        "moon_shadow: `git` did not answer at \{cwd}, reading .git instead",
      )
      @gitinfo.read_repo_info(cwd)
    }
  }
  match info.locate {
    @gitinfo.Ok => ()
    @gitinfo.Missing =>
      println(
        "moon_shadow: no git checkout at \{cwd}, baking in git_info().available = false",
      )
    @gitinfo.Unreadable =>
      println(
        "moon_shadow: \{cwd}/.git names a directory that is not there, baking in git_info().available = false",
      )
  }
  info.to_git_info()
}
