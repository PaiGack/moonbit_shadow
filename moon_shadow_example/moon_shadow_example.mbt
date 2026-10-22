///|
/// Describe the module this example was built in, through the library API.
pub fn describe() -> String {
  let info = @moon_shadow.current()
  "\{info.name}@\{info.version} (\{info.preferred_target})"
}

///|
/// The same values as seen by this module's own `shadow_impl` override.
pub fn own_metadata() -> String {
  let info = @shadow.module_info()
  "\{info.name}@\{info.version} (\{info.preferred_target})"
}
