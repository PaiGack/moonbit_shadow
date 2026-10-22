///|
/// Generated from `moon.mod`. Do not edit; run `moon check` to refresh.
pub fn module_info() -> @core.ModuleInfo {
  {
    name: "nrzhangsan/moon_shadow",
    version: "0.1.0",
    description: "Read a MoonBit module's own moon.mod metadata at runtime, baked in at build time.",
    license: "Apache-2.0",
    repository: "https://cnb.cool/nrzhangsan/moon_shadow",
    readme: "README.mbt.md",
    keywords: ["shadow", "build-info", "metadata"],
    preferred_target: "wasm-gc",
    supported_targets: [],
    deps: [
      { name: "moonbitlang/moon_config", version: "0.4.4" },
      { name: "moonbitlang/x", version: "0.5.6" },
    ],
  }
}
