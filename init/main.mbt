///|
/// One-command setup for consumers: write the `shadow` scaffold into a module.
///
/// Run it from the `moon_shadow` module root — the working directory
/// `shadow/moon.pkg`'s `init` dev_build rule already runs it in:
///
/// ```text
/// moon run --target js --target-dir _build/init init -- <module-dir>
/// ```
///
/// With no argument it discovers consumer modules itself: every `moon.mod`
/// near the library root that imports this module is a candidate, so the
/// `init` rule can run unattended during `moon check` / `moon build` /
/// `moon run`, exactly like the `gen` rule keeps `generated.mbt` fresh.
///
/// Everything written here is idempotent — a module that is already set up is
/// left completely untouched, and says nothing.
fn main {
  let args = @env.args()
  // The JS backend puts `node` plus the script path in front of the user's.
  let explicit : Array[String] = []
  for i = 2; i < args.length(); i = i + 1 {
    explicit.push(args[i])
  }
  let library = match @env.current_dir() {
    Some(dir) => dir
    None => {
      println("moon_shadow: cannot determine the current directory")
      return
    }
  }
  let module_name = match module_name_of(library) {
    Some(name) => name
    None => {
      println(
        "moon_shadow: run this from the moon_shadow module root — \{library}/moon.mod is missing or has no name",
      )
      return
    }
  }
  let targets = if explicit.is_empty() {
    discover(library, module_name)
  } else {
    explicit.map(fn(target) { absolute_path(target) })
  }
  for target in targets {
    let actions = init_module(library, module_name, target)
    if actions.is_empty() {
      if !explicit.is_empty() {
        println("moon_shadow: \{target} is already set up")
      }
      continue
    }
    println("moon_shadow: initialized \{target}")
    for action in actions {
      println("  \{action}")
    }
    if !explicit.is_empty() {
      println("  next: run `moon check` in \{target}")
    }
  }
}

///|
/// The module a directory belongs to, read from its `moon.mod`.
fn module_name_of(dir : String) -> String? {
  let source = match read_text(join(dir, "moon.mod")) {
    Some(source) => source
    None => return None
  }
  let info = @core.parse_moon_mod(source).info
  if info.name.is_empty() {
    None
  } else {
    Some(info.name)
  }
}

///|
/// Whether `dir`'s `moon.mod` declares a dependency on `module_name`.
fn imports_module(dir : String, module_name : String) -> Bool {
  let source = match read_text(join(dir, "moon.mod")) {
    Some(source) => source
    None => return false
  }
  let info = @core.parse_moon_mod(source).info
  for dep in info.deps {
    if dep.name == module_name {
      return true
    }
  }
  false
}

///|
/// Directories near the library root whose `moon.mod` imports `module_name`.
///
/// The documented setup keeps a library and its consumers in one tree:
/// consumers inside the library's repository, beside it, or with the library
/// nested inside them. So the library's own tree is scanned two levels deep,
/// its siblings one level, and the two direct ancestors are candidates too.
/// Every candidate is validated by parsing its `moon.mod`, so nothing that
/// does not depend on this module is ever touched.
fn discover(library : String, module_name : String) -> Array[String] {
  let candidates : Array[String] = []
  collect_dirs(library, 2, candidates)
  let parent = parent_of(library)
  if parent != library {
    collect_dirs(parent, 1, candidates)
    candidates.push(parent)
    candidates.push(parent_of(parent))
  }
  let consumers : Array[String] = []
  for dir in candidates {
    if dir == library || contains(consumers, dir) {
      continue
    }
    if imports_module(dir, module_name) {
      consumers.push(dir)
    }
  }
  consumers
}

///|
/// Collect subdirectories of `dir`, `depth` levels deep, skipping the ones no
/// MoonBit module lives in.
fn collect_dirs(dir : String, depth : Int32, out : Array[String]) -> Unit {
  if depth <= 0 {
    return
  }
  for name in list_dir(dir) {
    if name.has_prefix(".") ||
      name == "_build" ||
      name == "target" ||
      name == "node_modules" {
      continue
    }
    let child = join(dir, name)
    if !is_dir(child) {
      continue
    }
    out.push(child)
    collect_dirs(child, depth - 1, out)
  }
}

///|
/// Write the scaffold into `target`, returning what changed (empty when it
/// was already set up).
fn init_module(
  library : String,
  module_name : String,
  target : String,
) -> Array[String] {
  let actions : Array[String] = []
  let info = match module_info_of(target) {
    Some(info) => info
    None => {
      println("moon_shadow: \{target} has no readable moon.mod, skipped")
      return actions
    }
  }
  let lib_path = relative_path(target, library)
  // The gen rule runs `moon run <lib_path>/gen/main.mbt` from the module
  // root, which only resolves with the library in the module's workspace.
  if ensure_member(target, library, module_name, lib_path) {
    actions.push("moon.work: added member \{lib_path}")
  }
  let scaffold = render_scaffold(module_name, lib_path)
  let shadow_pkg = join(join(target, "shadow"), "moon.pkg")
  match read_text(shadow_pkg) {
    Some(existing) =>
      if existing != scaffold && is_our_scaffold(existing, module_name) {
        write_text(shadow_pkg, scaffold)
        actions.push("shadow/moon.pkg: updated")
      }
    None => {
      create_dir(join(target, "shadow"))
      write_text(shadow_pkg, scaffold)
      actions.push("shadow/moon.pkg: created")
    }
  }
  let generated = render_module_info_text(info)
  let generated_path = join(join(target, "shadow"), "generated.mbt")
  match read_text(generated_path) {
    Some(existing) =>
      if existing != generated {
        write_text(generated_path, generated)
        actions.push("shadow/generated.mbt: refreshed")
      }
    None => {
      write_text(generated_path, generated)
      actions.push("shadow/generated.mbt: created")
    }
  }
  for action in patch_manifest(target, module_name, info.name) {
    actions.push(action)
  }
  actions
}

///|
/// The full `ModuleInfo` of a directory, if it has a readable `moon.mod`.
fn module_info_of(dir : String) -> @core.ModuleInfo? {
  let source = match read_text(join(dir, "moon.mod")) {
    Some(source) => source
    None => return None
  }
  let parsed = @core.parse_moon_mod(source)
  if parsed.info.name.is_empty() {
    None
  } else {
    Some(parsed.info)
  }
}

///|
/// The `shadow` package manifest a consumer needs: implement the virtual
/// package, and regenerate `generated.mbt` from the consumer's `moon.mod`
/// on every build.
fn render_scaffold(module_name : String, lib_path : String) -> String {
  "import {\n  \"" +
  module_name +
  "/core\",\n}\n\nvirtual(implement: \"" +
  module_name +
  "/shadow\")\n\nrule(\n  name: \"gen\",\n  command: \"moon run --target js --target-dir _build/gen " +
  lib_path +
  "/gen/main.mbt -- $input $output\",\n)\n\ndev_build(rule: \"gen\", input: \"../moon.mod\", output: \"generated.mbt\")\n"
}

///|
/// Whether an existing `shadow/moon.pkg` is one of ours (and therefore safe
/// to rewrite when the library moved).
fn is_our_scaffold(text : String, module_name : String) -> Bool {
  text.contains("virtual(implement: \"" + module_name + "/shadow\")")
}

///|
/// The implementation file for a consumer's `shadow` package.
fn render_module_info_text(info : @core.ModuleInfo) -> String {
  @core.render_module_info(info)
}

///|
/// Make sure the consumer's `moon.work` lists the library as a member.
/// Returns whether it was changed.
fn ensure_member(
  target : String,
  library : String,
  module_name : String,
  lib_path : String,
) -> Bool {
  let path = join(target, "moon.work")
  let text = match read_text(path) {
    Some(text) => text
    None => {
      write_text(path, "members = [\n  \".\",\n  \"" + lib_path + "\",\n]\n")
      return true
    }
  }
  if has_member(text, target, library, module_name) {
    return false
  }
  match text.find("members = [") {
    Some(start) =>
      match find_from(text, "]", start) {
        Some(close) => {
          write_text(
            path,
            text[:close].to_owned() +
            "  \"" +
            lib_path +
            "\",\n" +
            text[close:].to_owned(),
          )
          true
        }
        None => false
      }
    None => {
      let prefix = if text.is_empty() || text.has_suffix("\n") {
        ""
      } else {
        "\n"
      }
      write_text(
        path,
        text + prefix + "members = [\n  \"" + lib_path + "\",\n]\n",
      )
      true
    }
  }
}

///|
/// Whether a `moon.work`'s member list already covers the library, either by
/// path or by module name.
fn has_member(
  text : String,
  target : String,
  library : String,
  module_name : String,
) -> Bool {
  for entry in member_entries(text) {
    if entry == "." {
      continue
    }
    let resolved = normalize_path(join(target, entry))
    if resolved == normalize_path(library) {
      return true
    }
    if module_name_of(resolved) == Some(module_name) {
      return true
    }
  }
  false
}

///|
/// The entries of a `moon.work` member list, in either spelling.
fn member_entries(text : String) -> Array[String] {
  let entries : Array[String] = []
  let marker = "members = ["
  match text.find(marker) {
    Some(start) =>
      match find_from(text, "[", start) {
        Some(open) =>
          match find_from(text, "]", open + 1) {
            Some(close) => {
              let inner = text[open + 1:close].to_owned()
              for token in inner.replace_all(old="\n", new=",").split(",") {
                let entry = token
                  .trim()
                  .to_owned()
                  .replace_all(old="\"", new="")
                if !entry.is_empty() {
                  entries.push(entry)
                }
              }
            }
            None => ()
          }
        None => ()
      }
    None => ()
  }
  entries
}

///|
/// Point the module's root package at its `shadow` implementation: the import
/// `moon add` would have added, and the `overrides` option that wires the
/// virtual package up.
fn patch_manifest(
  target : String,
  module_name : String,
  consumer_name : String,
) -> Array[String] {
  let actions : Array[String] = []
  let path = join(target, "moon.pkg")
  let text = match read_text(path) {
    Some(text) => text
    None => {
      println(
        "moon_shadow: \{target} has no moon.pkg — add `options(overrides: [ \"" +
        consumer_name +
        "/shadow\" ])` to the package that reads the metadata",
      )
      return actions
    }
  }
  let mut updated = text
  if !has_import(updated, module_name) {
    updated = add_import(updated, module_name)
    actions.push("moon.pkg: added import \{module_name}")
  }
  let shadow_pkg = consumer_name + "/shadow"
  if !has_import(updated, shadow_pkg) {
    updated = add_override(updated, shadow_pkg)
    actions.push("moon.pkg: added overrides \{shadow_pkg}")
  }
  if updated != text {
    write_text(path, updated)
  }
  actions
}

///|
/// Whether an `import { ... }` block, or an `overrides` list, already lists
/// `name`.
fn has_import(text : String, name : String) -> Bool {
  let quoted = "\"" + name + "\""
  for line in text.split("\n") {
    let entry = line.trim().to_owned()
    if entry == quoted || entry == quoted + "," {
      return true
    }
  }
  text.contains(quoted + ",") ||
  text.contains(quoted + " ]") ||
  text.contains(quoted + "]") ||
  text.contains(quoted + " }") ||
  text.contains("{ " + quoted)
}

///|
/// Add `name` to the first `import { ... }` block, or start one.
fn add_import(text : String, name : String) -> String {
  let entry = "  \"" + name + "\","
  match text.find("import {") {
    Some(start) =>
      match find_from(text, "}", start) {
        Some(close) =>
          text[:close].to_owned() + entry + "\n" + text[close:].to_owned()
        None => "import {\n" + entry + "\n}\n\n" + text
      }
    None => "import {\n" + entry + "\n}\n\n" + text
  }
}

///|
/// Add `shadow_pkg` to the `overrides` list: into the existing array if there
/// is one, otherwise as a new key — inside an existing `options(...)` block,
/// because `moon.pkg` takes only one.
fn add_override(text : String, shadow_pkg : String) -> String {
  let quoted = "\"" + shadow_pkg + "\""
  match text.find("overrides:") {
    Some(start) =>
      match find_from(text, "[", start) {
        Some(open) =>
          match find_from(text, "]", open + 1) {
            Some(close) => {
              let inner = text[open + 1:close].trim().to_owned()
              let filled = if inner.is_empty() {
                quoted + ","
              } else {
                inner + ", " + quoted + ","
              }
              text[:open + 1].to_owned() +
              " " +
              filled +
              " " +
              text[close:].to_owned()
            }
            None => text
          }
        None => text
      }
    None => insert_overrides_key(text, quoted)
  }
}

///|
/// Add the `overrides` key itself, as a new `options(...)` block or a new key
/// in the existing one.
fn insert_overrides_key(text : String, quoted : String) -> String {
  let entry = "  overrides: [ " + quoted + ", ],\n"
  match text.find("options(") {
    Some(start) =>
      match find_from(text, "\n", start) {
        Some(after) => text[:after].to_owned() + entry + text[after:].to_owned()
        None => text + entry
      }
    None => {
      let prefix = if text.is_empty() || text.has_suffix("\n") {
        ""
      } else {
        "\n"
      }
      text + prefix + "\noptions(\n" + entry + ")\n"
    }
  }
}

// -- paths ----------------------------------------------------------------

///|
/// Find `needle` at or after `from`, as an index into `text`.
fn find_from(text : String, needle : String, from : Int32) -> Int32? {
  match text[from:].find(needle) {
    Some(offset) => Some(from + offset)
    None => None
  }
}

///|
/// Whether `value` is in `values`.
fn contains(values : Array[String], value : String) -> Bool {
  for item in values {
    if item == value {
      return true
    }
  }
  false
}

///|
/// `path` as an absolute one, resolved against the current directory.
fn absolute_path(path : String) -> String {
  if is_absolute_path(path) {
    normalize_path(path)
  } else {
    let cwd = match @env.current_dir() {
      Some(dir) => dir
      None => "."
    }
    normalize_path(join(cwd, path))
  }
}

///|
/// Whether a path stands on its own: POSIX root, or a Windows drive.
fn is_absolute_path(path : String) -> Bool {
  if path.has_prefix("/") {
    true
  } else if path.length() >= 2 {
    match path.get_char(1) {
      Some(':') => true
      _ => false
    }
  } else {
    false
  }
}

///|
/// Drop `.` segments and resolve `..` where possible.
fn normalize_path(path : String) -> String {
  let segments = path_segments(path)
  if path.has_prefix("/") {
    "/" + segments.join("/")
  } else if segments.is_empty() {
    "."
  } else {
    segments.join("/")
  }
}

///|
/// The meaningful segments of a path, `.` dropped and `..` resolved.
fn path_segments(path : String) -> Array[String] {
  let segments : Array[String] = []
  for segment in path.replace_all(old="\\", new="/").split("/") {
    let part = segment.to_owned()
    if part.is_empty() || part == "." {
      continue
    }
    if part == ".." {
      if segments.length() > 0 && segments[segments.length() - 1] != ".." {
        ignore(segments.pop())
      } else {
        segments.push("..")
      }
      continue
    }
    segments.push(part)
  }
  segments
}

///|
/// The path from `from` to `to`, both absolute.
fn relative_path(from : String, to : String) -> String {
  let from_segments = path_segments(from)
  let to_segments = path_segments(to)
  let mut common = 0
  while common < from_segments.length() &&
        common < to_segments.length() &&
        from_segments[common] == to_segments[common] {
    common = common + 1
  }
  let parts : Array[String] = []
  for _up = 0; _up < from_segments.length() - common; _up = _up + 1 {
    parts.push("..")
  }
  for i = common; i < to_segments.length(); i = i + 1 {
    parts.push(to_segments[i])
  }
  if parts.is_empty() {
    "."
  } else {
    parts.join("/")
  }
}

///|
/// The directory a path lives in.
fn parent_of(path : String) -> String {
  let flat = path.replace_all(old="\\", new="/")
  match flat.rev_find("/") {
    Some(idx) => if idx == 0 { "/" } else { flat[:idx].to_owned() }
    None => flat
  }
}

///|
/// Join two path fragments with a single separator.
fn join(dir : String, name : String) -> String {
  if dir.is_empty() {
    name
  } else if dir.has_suffix("/") {
    dir + name
  } else {
    dir + "/" + name
  }
}

// -- files ----------------------------------------------------------------

///|
/// Read a file, `None` when it cannot be read.
fn read_text(path : String) -> String? {
  let content = @fs.read_file_to_string(path) catch { _ => return None }
  Some(content)
}

///|
/// Write a file, reporting failure without aborting the build.
fn write_text(path : String, content : String) -> Unit {
  @fs.write_string_to_file(path, content) catch {
    _ => println("moon_shadow: cannot write \{path}")
  }
}

///|
/// Create a directory, ignoring one that already exists.
fn create_dir(path : String) -> Unit {
  @fs.create_dir(path) catch {
    _ => ()
  }
}

///|
/// The names in a directory, empty when it cannot be read.
fn list_dir(path : String) -> Array[String] {
  let entries = @fs.read_dir(path) catch { _ => return [] }
  let names : Array[String] = []
  for entry in entries {
    names.push(entry)
  }
  names
}

///|
/// Whether a path is a directory.
fn is_dir(path : String) -> Bool {
  @fs.is_dir(path) catch {
    _ => false
  }
}
