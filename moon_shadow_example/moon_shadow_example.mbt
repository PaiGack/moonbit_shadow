///|
/// Describe the module this example was built in, using `moon_shadow`.
pub fn describe() -> String {
  let info = @moon_shadow_info.current()
  "\{info.name}@\{info.version} (\{info.preferred_target})"
}

///|
/// The metadata the example's own `shadow_impl` supplied for this module.
pub fn own_metadata() -> String {
  "\{@moon_shadow_shadow.module_name()}@\{@moon_shadow_shadow.module_version()} (\{@moon_shadow_shadow.module_preferred_target()})"
}
