///|
/// Metadata of a MoonBit module, read from its `moon.mod`.
///
/// Every field is baked into the binary at build time, so reading them never
/// touches the filesystem and programs do not need to ship `moon.mod`.
pub(all) struct ModuleInfo {
  name : String
  version : String
  description : String
  license : String
  repository : String
  readme : String
  keywords : Array[String]
  preferred_target : String
} derive(Debug, Eq)

///|
/// Metadata of the module that pulled `moon_shadow` in.
pub fn current() -> ModuleInfo {
  {
    name: @shadow.module_name(),
    version: @shadow.module_version(),
    description: @shadow.module_description(),
    license: @shadow.module_license(),
    repository: @shadow.module_repository(),
    readme: @shadow.module_readme(),
    keywords: @shadow.module_keywords(),
    preferred_target: @shadow.module_preferred_target(),
  }
}

///|
/// `"username/pkg@0.1.0"`, the shape `moon add` accepts.
pub fn ModuleInfo::long_version(self : ModuleInfo) -> String {
  if self.version == "" {
    self.name
  } else {
    "\{self.name}@\{self.version}"
  }
}
