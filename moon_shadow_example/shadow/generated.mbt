///|
/// Generated from `moon.mod`. Keep in sync when `moon.mod` changes.
pub fn module_info() -> @PaiGack/moon_shadow/mooninfo.ModuleInfo {
  {
    name: "PaiGack/moon_shadow_example",
    version: "999.999.999",
    description: "How to read your own moon.mod at runtime with moon_shadow.",
    license: "Apache-2.0",
    repository: "",
    readme: "README.mbt.md",
    keywords: ["shadow", "example"],
    preferred_target: "wasm-gc",
    supported_targets: [],
    deps: [
      { name: "PaiGack/moon_shadow", version: "0.1.1" },
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

