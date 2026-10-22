///|
fn sample() -> @gitinfo.RawGitInfo {
  {
    branch: "main\n",
    tag: "",
    describe: "v0.1.1-3-gabc1234\n",
    commit: "abc1234def5678\n",
    short_commit: "abc1234\n",
    commit_date: "2026-10-22T09:14:41+00:00\n",
    author: "Pai2s\n",
    email: "pai2s@example.com\n",
    status: "",
    upstream_count: "2\t5\n",
  }
}

///|
test "raw output becomes fields" {
  let info = sample().to_git_info()
  assert_eq(info.available, true)
  assert_eq(info.branch, "main")
  assert_eq(info.tag, "")
  assert_eq(info.describe, "v0.1.1-3-gabc1234")
  assert_eq(info.commit, "abc1234def5678")
  assert_eq(info.short_commit, "abc1234")
  assert_eq(info.commit_date, "2026-10-22T09:14:41+00:00")
  assert_eq(info.author, "Pai2s")
  assert_eq(info.email, "pai2s@example.com")
  assert_eq(info.dirty, false)
  assert_eq((info.ahead, info.behind), (2, 5))
}

///|
test "dirty follows status output" {
  let raw : @gitinfo.RawGitInfo = {
    ..sample(),
    status: " M shadow/generated.mbt\n",
  }
  assert_true(raw.to_git_info().dirty)
  let untracked_only : @gitinfo.RawGitInfo = { ..sample(), status: "  \n", }
  assert_false(untracked_only.to_git_info().dirty)
}

///|
test "no upstream means zero ahead and behind" {
  let raw : @gitinfo.RawGitInfo = { ..sample(), upstream_count: "", }
  let info = raw.to_git_info()
  assert_eq((info.ahead, info.behind), (0, 0))
  let garbage : @gitinfo.RawGitInfo = { ..sample(), upstream_count: "oops", }
  assert_eq((garbage.to_git_info().ahead, garbage.to_git_info().behind), (0, 0))
}

///|
test "detached head and missing tag stay empty" {
  let raw : @gitinfo.RawGitInfo = {
    ..sample(),
    branch: "",
    tag: "",
    describe: "",
  }
  let info = raw.to_git_info()
  assert_eq(info.branch, "")
  assert_eq(info.tag, "")
  assert_eq(info.describe, "abc1234")
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
