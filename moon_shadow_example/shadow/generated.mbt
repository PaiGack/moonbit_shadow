///|
/// Generated from `moon.mod`. Keep in sync when `moon.mod` changes.
pub fn module_info() -> @core.ModuleInfo {
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
    deps: [{ name: "PaiGack/moon_shadow", version: "0.1.1", }],
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
