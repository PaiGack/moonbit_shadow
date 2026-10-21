///|
pub let module_info : @modinfo_types.ModuleInfo = {
  name: "nrzhangsan/moon_shadow",
  version: "0.1.0",
  description: "Build-time module metadata for MoonBit, in the spirit of shadow-rs",
  license: "Apache-2.0",
  repository: "https://cnb.cool/nrzhangsan/moon_shadow",
  readme: "README.mbt.md",
  keywords: ["metadata", "build-info", "moon.mod"],
  preferred_target: "wasm-gc",
  supported_targets: [],
  deps: [
    { name: "moonbitlang/moon_config", version: "0.4.4" },
    { name: "moonbitlang/x", version: "0.5.6" },
  ],
}
