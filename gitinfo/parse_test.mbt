///|
fn sample() -> @gitinfo.RepoInfo {
  {
    available: true,
    locate: Ok,
    branch: "main",
    tag: "v0.1.1",
    describe: "v0.1.1",
    commit: "abc1234def5678",
    short_commit: "abc1234",
    commit_date: "2026-10-22T09:14:41+00:00",
    author: "Pai2s",
    email: "pai2s@example.com",
    dirty: true,
    ahead: 2,
    behind: 5,
  }
}

///|
test "a read repository becomes fields" {
  let info = sample().to_git_info()
  assert_eq(info.available, true)
  assert_eq(info.branch, "main")
  assert_eq(info.tag, "v0.1.1")
  assert_eq(info.describe, "v0.1.1")
  assert_eq(info.commit, "abc1234def5678")
  assert_eq(info.short_commit, "abc1234")
  assert_eq(info.commit_date, "2026-10-22T09:14:41+00:00")
  assert_eq(info.author, "Pai2s")
  assert_eq(info.email, "pai2s@example.com")
  assert_eq(info.dirty, true)
  assert_eq((info.ahead, info.behind), (2, 5))
}

///|
test "ref files lose their line ending" {
  let raw : @gitinfo.RepoInfo = {
    ..sample(),
    branch: "main\r\n",
    commit: "abc1234def5678\n",
  }
  let info = raw.to_git_info()
  assert_eq(info.branch, "main")
  assert_eq(info.commit, "abc1234def5678")
}

///|
test "a missing repository clears every field" {
  let raw : @gitinfo.RepoInfo = {
    ..sample(),
    available: false,
    locate: Missing,
  }
  let info = raw.to_git_info()
  assert_false(info.available)
  assert_false(info.dirty)
  assert_eq((info.ahead, info.behind), (0, 0))
  // The cause survives: it is what the generator prints.
  assert_eq(raw.locate, Missing)
}

///|
test "a half-written .git is not a repository" {
  // `.git` was found, but `HEAD` names nothing: the refs above it are stale,
  // and a stale version number is worse than none.
  let info = { ..sample(), available: false, locate: Unreadable, }.to_git_info()
  assert_false(info.available)
  assert_eq(info.to_version_string(), "unavailable")
}

///|
test "detached head and missing tag stay empty" {
  let raw : @gitinfo.RepoInfo = {
    ..sample(),
    branch: "",
    tag: "",
    describe: "",
  }
  let info = raw.to_git_info()
  assert_eq(info.branch, "")
  assert_eq(info.tag, "")
  assert_eq(info.describe, "")
}

///|
test "commit lines split on NUL" {
  let (date, author, email) = @gitinfo.parse_commit_lines(
    "2026-10-22T09:14:41+00:00\u{0}Pai2s\u{0}pai2s@example.com\n",
  )
  assert_eq(date, "2026-10-22T09:14:41+00:00")
  assert_eq(author, "Pai2s")
  assert_eq(email, "pai2s@example.com")
}

///|
test "a commit line that is not three fields answers nothing" {
  assert_eq(@gitinfo.parse_commit_lines(""), ("", "", ""))
  assert_eq(@gitinfo.parse_commit_lines("only\u{0}two"), ("", "", ""))
}

///|
test "available false reads as unavailable" {
  let info = @gitinfo.GitInfo::none()
  assert_false(info.available)
  assert_eq(info.describe_version(), "")
  assert_eq(info.commit_version(), "")
  assert_eq(info.to_version_string(), "unavailable")
}

///|
test "version strings prefer the most specific name" {
  let mut info = @gitinfo.GitInfo::none()
  info = {
    ..info,
    available: true,
    branch: "main",
    describe: "v0.1.1-3-gabc1234",
  }
  info = { ..info, commit: "abc1234def5678", short_commit: "abc1234", }
  assert_eq(info.describe_version(), "main")
  assert_eq(info.to_version_string(), "main abc1234")
  let tagged : @gitinfo.GitInfo = { ..info, tag: "v1.0.0", }
  assert_eq(tagged.describe_version(), "v1.0.0")
  let detached : @gitinfo.GitInfo = { ..info, branch: "", }
  assert_eq(detached.describe_version(), "v0.1.1-3-gabc1234")
}

///|
test "dirty shows up in the version strings" {
  let info : @gitinfo.GitInfo = {
    ..@gitinfo.GitInfo::none(),
    available: true,
    branch: "main",
    commit: "abc1234def5678",
    short_commit: "abc1234",
    dirty: true,
  }
  assert_eq(info.describe_version(), "main-dirty")
  assert_eq(info.commit_version(), "abc1234def5678-dirty")
  assert_eq(info.to_version_string(), "main-dirty abc1234-dirty")
}
