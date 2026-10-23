///|
/// The `build_info()` implementation: what the generator writes into a virtual
/// package implementation, and what this package's own `shadow/generated.mbt`
/// already contains.
///
/// One function, not two fields: the implementation hands back a `BuildInfo` and
/// `BuildInfo::from_toolchain` in this package attaches the profile and the
/// backend to it. Both sides are compiled for the same target with the same
/// profile — they are packages of one application — so the profile is asked for
/// once, at the place that can also see it, rather than sent across the boundary
/// as two more strings.
///
/// Deterministic, so regenerating from the same toolchain yields no diff.
///
/// `pkg_path` is the full package path of `buildinfo`, the way the hand written
/// `pkg.mbti` of an implementation spells it. See `mooninfo`'s renderer.
pub fn render_build_info(info : ToolchainInfo, pkg_path~ : String) -> String {
  let lines : Array[String] = [
    "///|",
    "/// Generated from `moon version --all`. Keep in sync with the toolchain.",
    "pub fn build_info() -> @\{pkg_path}.BuildInfo {",
    "  @\{pkg_path}.BuildInfo::from_toolchain({",
    "    moon_version: \{@mooninfo.quote(info.moon_version)},",
    "    moonc_version: \{@mooninfo.quote(info.moonc_version)},",
    "  })",
    "}",
  ]
  lines.join("\n") + "\n"
}
