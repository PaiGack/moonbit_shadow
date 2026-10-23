///|
/// Generated from `moon.mod`. Keep in sync when `moon.mod` changes.
pub fn module_info() -> @PaiGack/moon_shadow/mooninfo.ModuleInfo {
  {
    name: "PaiGack/moon_shadow",
    version: "0.2.3",
    description: "Read a MoonBit module's own moon.mod and git metadata at runtime, baked in at build time.",
    license: "Apache-2.0",
    repository: "https://github.com/PaiGack/moonbit_shadow",
    readme: "README.mbt.md",
    keywords: ["shadow", "build-info", "metadata"],
    preferred_target: "wasm-gc",
    supported_targets: [],
    deps: [
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
    describe: "514baa6",
    commit: "514baa63b64db711bccb8e4008158ced7128c794",
    short_commit: "514baa6",
    commit_date: "2026-10-23T09:06:56+08:00",
    author: "rzhangsan",
    email: "4iNtJYlBfhr1QT8bkeMawE+rzhangsan@noreply.cnb.cool",
    dirty: true,
    ahead: 0,
    behind: 0,
  }
}
