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
    describe: "530e4d7",
    commit: "530e4d7f379303100732b9444ed3c1bb0ae21998",
    short_commit: "530e4d7",
    commit_date: "",
    author: "",
    email: "",
    dirty: false,
    ahead: 0,
    behind: 0,
  }
}
