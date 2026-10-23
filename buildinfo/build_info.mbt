///|
/// The toolchain that compiled this application, plus the variant it was
/// compiled in.
///
/// Every field is a string: it ends up in `--version` output or a log line, and
/// nothing here is worth formatting twice. `debug` and `release` are the profile
/// as a marker — one of them is `""`, so the struct can be read the way
/// `--version` output usually is: append whatever is non-empty.
pub(all) struct BuildInfo {
  /// `moon`'s version, as reported by `moon version --all`.
  moon_version : String
  /// `moonc`'s version, including its build hash.
  moonc_version : String
  /// `debug` or `release`.
  profile : String
  /// Backend this package was compiled for: `wasm-gc`, `js`, `native`...
  target : String
  /// `"debug"`, or `""` when this is a release build.
  debug : String
  /// `"release"`, or `""` when this is a debug build.
  release : String
} derive(Eq, Debug)

///|
#deprecated
pub extend BuildInfo with Eq::{not_equal, equal}

///|
#deprecated
pub extend BuildInfo with Debug::{to_repr}

///|
/// The application's own answers — profile and backend — plus the toolchain the
/// generator captured.
///
/// The join: `gen` knows the toolchain and writes it into the virtual package
/// implementation, this package knows the profile and backend because they are
/// `targets`-selected files, and neither can see the other's half. Keeping the
/// join in one function means the struct literal appears once, not twice.
pub fn BuildInfo::from_toolchain(toolchain : ToolchainInfo) -> BuildInfo {
  {
    moon_version: toolchain.moon_version,
    moonc_version: toolchain.moonc_version,
    profile,
    target,
    debug,
    release,
  }
}

///|
/// `moon 0.1.20261020`, `""` when the generator could not read it.
pub fn BuildInfo::moon(self : BuildInfo) -> String {
  prefixed("moon", self.moon_version)
}

///|
/// `moonc v0.10.16+b1a0e846e`, `""` when the generator could not read it.
pub fn BuildInfo::moonc(self : BuildInfo) -> String {
  prefixed("moonc", self.moonc_version)
}
