///|
/// The checkout at `cwd`, read straight out of the files `git` would read.
///
/// The generator is a build tool that has to run wherever `moon` runs, and
/// starting a child process is the least portable thing it could do. Every file
/// a `.git` holds is plain — `HEAD`, the ref it names, `packed-refs`, a loose
/// commit object, the index — so the reading lives in `gitinfo` and this is
/// just the call plus the one line worth printing.
fn collect_git_info(cwd : String) -> @gitinfo.GitInfo {
  let info = @gitinfo.read_repo_info(cwd)
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
