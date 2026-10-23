///|
/// `moon.mod` metadata of the module whose build compiled this package.
///
/// The value crosses the build boundary through the `shadow` virtual package,
/// which a consumer overrides with its own implementation, so no `moon.mod` is
/// read and no file is touched at runtime.
pub fn current() -> @mooninfo.ModuleInfo {
  @shadow.module_info()
}

///|
/// Git state of the checkout that built this package.
///
/// Captured once by the `gen` rule and compiled in, for the same reason as
/// `current()`: the machine running the software has no `.git`, maybe no
/// `git`, and its cwd has nothing to do with your repository.
///
/// `available = false` when the build itself happened outside a git work tree.
pub fn git() -> @gitinfo.GitInfo {
  @shadow.git_info()
}

///|
/// The toolchain that compiled this package, and the `profile` / `target` it
/// was compiled for.
///
/// A struct, not the `(String, String)` the generator happens to read: the
/// virtual package's accessor returns a `BuildInfo`, so adding a field later
/// (channel, host, build date) does not break every caller, and the two
/// strings arrive with a name each instead of an order to remember.
///
/// Same rule as the other two: baked in at build time, nothing read at
/// runtime, and the profile is the one selected for *this* build.
pub fn build() -> @buildinfo.BuildInfo {
  @shadow.build_info()
}
