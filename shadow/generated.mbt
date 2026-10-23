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
    describe: "3d11c12",
    commit: "3d11c12bb76b6129eff5cdf37ad367c06183382e",
    short_commit: "3d11c12",
    commit_date: "",
    author: "",
    email: "",
    dirty: true,
    ahead: 0,
    behind: 0,
  }
}

///|
/// Toolchain versions captured when the generator ran.
pub fn toolchain_versions() -> (String, String) {
  ("0.1.20261020", "v0.10.16+b1a0e846e")
}
