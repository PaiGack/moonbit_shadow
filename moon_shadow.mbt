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
