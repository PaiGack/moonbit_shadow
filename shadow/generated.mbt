///|
/// Generated from `moon.mod`. Keep in sync when `moon.mod` changes.
pub fn module_info() -> @PaiGack/moon_shadow/mooninfo.ModuleInfo {
  {
    name: "PaiGack/moon_shadow",
    version: "0.3.2",
    description: "Read a MoonBit module's own moon.mod and git metadata at runtime, baked in at build time.",
    license: "Apache-2.0",
    repository: "https://github.com/PaiGack/moonbit_shadow",
    readme: "README.mbt.md",
    keywords: ["shadow", "build-info", "metadata", "git-info"],
    preferred_target: "wasm-gc",
    supported_targets: [],
    deps: [
      { name: "moonbitlang/async", version: "0.22.5" },
      { name: "moonbitlang/moon_config", version: "0.4.5" },
      { name: "moonbitlang/x", version: "0.5.6" },
    ],
  }
}

///|
/// Generated from the git checkout this module was built in.
pub fn git_info() -> @PaiGack/moon_shadow/gitinfo.GitInfo {
  {
    available: true,
    branch: "main",
    tag: "",
    describe: "024004e",
    commit: "024004e3d1eccacbd3fea8fcfe7a80735563301f",
    short_commit: "024004e",
    commit_date: "2026-10-23T18:54:18+08:00",
    author: "rzhangsan",
    email: "4iNtJYlBfhr1QT8bkeMawE+rzhangsan@noreply.cnb.cool",
    dirty: true,
    ahead: 0,
    behind: 0,
  }
}

///|
/// Generated from `moon version --all`. Keep in sync with the toolchain.
pub fn build_info() -> @PaiGack/moon_shadow/buildinfo.BuildInfo {
  @PaiGack/moon_shadow/buildinfo.BuildInfo::from_toolchain({
    moon_version: "0.1.20261023",
    moonc_version: "v0.10.17+d971670cd",
  })
}

