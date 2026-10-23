///|
test "render_build_info spells its type by full package path" {
  let out = render_build_info(
    { moon_version: "0.1.20261020", moonc_version: "v0.10.16+b1a0e846e", },
    pkg_path="PaiGack/moon_shadow/buildinfo",
  )
  assert_true(
    out.contains(
      "pub fn build_info() -> @PaiGack/moon_shadow/buildinfo.BuildInfo {",
    ),
  )
  assert_true(
    out.contains("@PaiGack/moon_shadow/buildinfo.BuildInfo::from_toolchain({"),
  )
  assert_true(out.contains("moon_version: \"0.1.20261020\","))
  assert_true(out.contains("moonc_version: \"v0.10.16+b1a0e846e\","))
}

///|
test "render_build_info survives an unreadable toolchain" {
  let out = render_build_info(ToolchainInfo::empty(), pkg_path="shadow")
  assert_true(out.contains("moon_version: \"\","))
  assert_true(out.contains("moonc_version: \"\","))
}

///|
test "version helpers keep the tool's name" {
  let info = { moon_version: "0.1.20261020", moonc_version: "", }
  assert_true(info.moon() == "moon 0.1.20261020")
  assert_true(info.moonc() == "")
}

///|
test "from_toolchain attaches the profile and backend" {
  let build = BuildInfo::from_toolchain({
    moon_version: "0.1.20261020",
    moonc_version: "v0.10.16+b1a0e846e",
  })
  assert_eq(build.moon(), "moon 0.1.20261020")
  assert_true(build.profile == "debug" || build.profile == "release")
  assert_true(!build.target.is_empty())
  assert_true(build.debug.is_empty() != build.release.is_empty())
}
