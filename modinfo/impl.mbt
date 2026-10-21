///|
/// `moon.mod` metadata of the module whose build compiled this package.
///
/// `dev_build` writes it into `module_info.mbt` and the file is committed, so
/// it travels inside the artifact: no `moon.mod` is read at runtime.
pub fn current() -> @modinfo_types.ModuleInfo {
  module_info
}
