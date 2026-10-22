///|
/// `moon.mod` metadata of the module whose build compiled this package.
///
/// The value crosses the build boundary through the `shadow` virtual package,
/// which a consumer overrides with its own implementation, so no `moon.mod` is
/// read and no file is touched at runtime.
pub fn current() -> @core.ModuleInfo {
  @shadow.module_info()
}
