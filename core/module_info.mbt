///|
/// One entry of `import { ... }` in `moon.mod`, name and version split apart.
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
/// A snapshot of `moon.mod`, rendered into the artifact at build time.
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

///|
/// Look a dependency up by module name.
pub fn ModuleInfo::dep(self : ModuleInfo, name : String) -> Dependency? {
  for dep in self.deps {
    if dep.name == name {
      return Some(dep)
    }
  }
  None
}

///|
/// `<name>@<version>`, the shape `moon add` accepts.
pub fn ModuleInfo::long_version(self : ModuleInfo) -> String {
  if self.version.is_empty() {
    self.name
  } else {
    "\{self.name}@\{self.version}"
  }
}

///|
/// `<name> <version> (<short info>)`, the shape used by `--version` output.
pub fn ModuleInfo::to_long_version_string(self : ModuleInfo) -> String {
  let parts : Array[String] = []
  for part in [self.name, self.version] {
    if !part.is_empty() {
      parts.push(part)
    }
  }
  let line = parts.join(" ")
  if self.description.is_empty() {
    if self.repository.is_empty() {
      line
    } else {
      "\{line} from \{self.repository}"
    }
  } else if self.repository.is_empty() {
    "\{line} \{self.description}"
  } else {
    "\{line} from \{self.repository} \{self.description}"
  }
}
