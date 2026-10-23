///|
/// Describe the module this example was built in, through the library API.
pub fn describe() -> String {
  let info = @moon_shadow.current()
  "\{info.name}@\{info.version} (\{info.preferred_target})"
}

///|
/// The same values as seen by this module's own `shadow/` override.
pub fn own_metadata() -> String {
  let info = @shadow.module_info()
  "\{info.name}@\{info.version} (\{info.preferred_target})"
}

///|
/// Git state of this example's own checkout, baked in at build time.
pub fn git_describe() -> String {
  let git = @moon_shadow.git()
  if !git.available {
    return "unavailable"
  }
  git.to_version_string()
}

///|
/// The toolchain and variant this example was built with, as its own `shadow/`
/// recorded them.
///
/// `build_info()` comes from the virtual package, the same way `current()` and
/// `git()` do: this module's `overrides` points at its own `shadow/`, so the
/// values are its own build's, not the library's.
pub fn build_describe() -> String {
  let build = @shadow.build_info()
  "\{build.moon()} / \{build.moonc()} / \{build.profile} \{build.target}"
}
