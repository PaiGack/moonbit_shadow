///|
/// Generated from `moon.mod`. Keep in sync when `moon.mod` changes.
pub fn module_info() -> @core.ModuleInfo {
  {
    name: "PaiGack/moon_shadow",
    version: "0.1.1",
    description: "Read a MoonBit module's own moon.mod metadata at runtime, baked in at build time.",
    license: "Apache-2.0",
    repository: "https://github.com/PaiGack/moonbit_shadow",
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
