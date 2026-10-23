///|
pub(all) struct BuildInfo {
  moon_version : String
  moonc_version : String
  profile : String
  target : String
} derive(Eq, Debug)

///|
#deprecated
pub extend BuildInfo with Eq::{not_equal, equal}

///|
#deprecated
pub extend BuildInfo with Debug::{to_repr}

///|
/// Toolchain versions captured by the generator, with the profile and backend
/// selected when this package is compiled into the application.
pub let info : BuildInfo = {
  let (moon_version, moonc_version) = @shadow.toolchain_versions()
  { moon_version, moonc_version, profile, target, }
}
