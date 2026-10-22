///|
/// One entry of `import { ... }` in `moon.mod`.
pub(all) struct Dependency {
  name : String
  version : String
} derive(Eq, Debug)

///|
#deprecated
pub extend Dependency with Eq::{not_equal, equal}

///|
#deprecated
pub extend Dependency with Debug::{to_repr}

///|
pub(all) struct ModuleInfo {
  name : String
  version : String
  description : String
  license : String
  repository : String
  readme : String
  keywords : Array[String]
  preferred_target : String
  supported_targets : Array[String]
  deps : Array[Dependency]
} derive(Eq, Debug)

///|
#deprecated
pub extend ModuleInfo with Eq::{not_equal, equal}

///|
#deprecated
pub extend ModuleInfo with Debug::{to_repr}

///|
pub fn ModuleInfo::dep(self : ModuleInfo, name : String) -> Dependency? {
  let mut found : Dependency? = None
  for dep in self.deps {
    if dep.name == name && found is None {
      found = Some(dep)
    }
  }
  found
}

///|
/// `<name> <version> (<short info>)`, the shape used by `--version` output.
pub fn ModuleInfo::to_long_version_string(self : ModuleInfo) -> String {
  let parts : Array[String] = ["\{self.name} \{self.version}"]
  if !self.repository.is_empty() {
    parts.push("from \{self.repository}")
  }
  if !self.description.is_empty() {
    parts.push(self.description)
  }
  parts.join(" ")
}

///|
pub fn ModuleInfo::empty() -> ModuleInfo {
  {
    name: "",
    version: "",
    description: "",
    license: "",
    repository: "",
    readme: "",
    keywords: [],
    preferred_target: "",
    supported_targets: [],
    deps: [],
  }
}
