///|
/// Generated from `moon.mod`. Keep in sync when `moon.mod` changes.
pub fn module_info() -> @core.ModuleInfo {
  {
    name: "PaiGack/moon_shadow",
    version: "0.1.1",
    description: "Read a MoonBit module's own moon.mod and git metadata at runtime, baked in at build time.",
    license: "Apache-2.0",
    repository: "https://github.com/PaiGack/moonbit_shadow",
    readme: "README.mbt.md",
    keywords: ["shadow", "build-info", "metadata"],
    preferred_target: "wasm-gc",
    supported_targets: [],
    deps: [
      { name: "moonbitlang/moon_config", version: "0.4.4", },
      { name: "moonbitlang/x", version: "0.5.6", },
    ],
  }
}

///|
/// Generated from the git checkout this module was built in.
pub fn git_info() -> @gitinfo.GitInfo {
  {
    available: true,
    branch: "main",
    tag: "",
    describe: "50a396b",
    commit: "50a396b36f3d6bf8cbaf593ebe294609fefb92bc",
    short_commit: "50a396b",
    commit_date: "2026-10-22T18:50:55+08:00",
    author: "rzhangsan",
    email: "4iNtJYlBfhr1QT8bkeMawE+rzhangsan@noreply.cnb.cool",
    dirty: true,
    ahead: 0,
    behind: 0,
  }
}
