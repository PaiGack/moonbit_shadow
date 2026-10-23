///|
/// `moon` and `moonc` as reported by `moon version --all` when the generator
/// ran.
///
/// A struct rather than a `(String, String)` tuple: a later field (channel,
/// host, build date) is then an additive change instead of a breaking one, and
/// the name says what the pair belonged to. The generator writes a value of this
/// type into the virtual package implementation, and `BuildInfo::from_toolchain`
/// turns that value into the whole picture of the build.
pub(all) struct ToolchainInfo {
  moon_version : String
  moonc_version : String
} derive(Eq, Debug)

///|
#deprecated
pub extend ToolchainInfo with Eq::{not_equal, equal}

///|
#deprecated
pub extend ToolchainInfo with Debug::{to_repr}

///|
pub fn ToolchainInfo::empty() -> ToolchainInfo {
  { moon_version: "", moonc_version: "", }
}

///|
/// `moon 0.1.20261020`, `""` when the generator could not read it.
pub fn ToolchainInfo::moon(self : ToolchainInfo) -> String {
  prefixed("moon", self.moon_version)
}

///|
/// `moonc v0.10.16+b1a0e846e`, `""` when the generator could not read it.
pub fn ToolchainInfo::moonc(self : ToolchainInfo) -> String {
  prefixed("moonc", self.moonc_version)
}

///|
fn prefixed(tool : String, version : String) -> String {
  if version.is_empty() {
    ""
  } else {
    "\{tool} \{version}"
  }
}
