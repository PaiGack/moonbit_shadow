///|
/// Describe the module this example was built in, using `moon_shadow`.
pub fn describe() -> String {
  let info = @moon_shadow.current()
  "\{info.long_version()} (\{info.preferred_target})"
}
