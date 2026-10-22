///|
/// Whitebox tests for the init package: the path math and the manifest
/// patching are where the subtle mistakes live, plus one full run against a
/// throwaway module.

///|
fn must_read(path : String) -> String {
  match read_text(path) {
    Some(text) => text
    None => "<missing>"
  }
}

///|
fn remove_tree(path : String) -> Unit {
  if is_dir(path) {
    for name in list_dir(path) {
      remove_tree(join(path, name))
    }
    @fs.remove_dir(path) catch {
      _ => ()
    }
  } else if @fs.path_exists(path) {
    @fs.remove_file(path) catch {
      _ => ()
    }
  }
}

///|
test "normalize_path drops . and resolves .." {
  assert_eq(normalize_path("/a/b/../c"), "/a/c")
  assert_eq(normalize_path("/a/./b//c"), "/a/b/c")
  assert_eq(normalize_path("a/b"), "a/b")
  assert_eq(normalize_path("/"), "/")
  assert_eq(normalize_path(""), ".")
}

///|
test "relative_path walks up and down" {
  assert_eq(
    relative_path("/repo/app", "/repo/libs/moon_shadow"),
    "../libs/moon_shadow",
  )
  assert_eq(relative_path("/repo/libs/moon_shadow", "/repo/app"), "../../app")
  assert_eq(relative_path("/a/b", "/a/b"), ".")
}

///|
test "parent_of peels one level" {
  assert_eq(parent_of("/a/b"), "/a")
  assert_eq(parent_of("/a"), "/")
  assert_eq(parent_of("a"), "a")
}

///|
test "has_import sees every spelling" {
  let one_per_line = "import {\n  \"PaiGack/moon_shadow\",\n}\n"
  assert_true(has_import(one_per_line, "PaiGack/moon_shadow"))
  assert_false(has_import(one_per_line, "PaiGack/moon_shadow/shadow"))
  let single_line = "import { \"a/b\", \"c/d\" }"
  assert_true(has_import(single_line, "a/b"))
  assert_true(has_import(single_line, "c/d"))
  let no_comma = "options(\n  overrides: [ \"acme/x/shadow\" ],\n)"
  assert_true(has_import(no_comma, "acme/x/shadow"))
  let with_comma = "options(\n  overrides: [ \"acme/x/shadow\", ],\n)"
  assert_true(has_import(with_comma, "acme/x/shadow"))
  let other = "options(\n  overrides: [ \"other/shadow\" ],\n)"
  assert_false(has_import(other, "acme/x/shadow"))
}

///|
test "add_import extends the first block or starts one" {
  let with_block = "import {\n  \"other/mod\",\n}\n\npkgtype(kind: \"library\")\n"
  let patched = add_import(with_block, "PaiGack/moon_shadow")
  assert_true(patched.contains("  \"PaiGack/moon_shadow\",\n"))
  assert_true(patched.contains("  \"other/mod\",\n"))
  assert_true(has_import(patched, "PaiGack/moon_shadow"))
  let fresh = "pkgtype(kind: \"library\")\n"
  let started = add_import(fresh, "PaiGack/moon_shadow")
  assert_true(
    started.has_prefix("import {\n  \"PaiGack/moon_shadow\",\n}\n\n"),
  )
}

///|
test "add_override appends a block, a key, or an entry" {
  let plain = "import {\n  \"PaiGack/moon_shadow\",\n}\n"
  let block = add_override(plain, "acme/x/shadow")
  assert_true(
    block.contains("options(\n  overrides: [ \"acme/x/shadow\", ],\n)"),
  )
  assert_true(has_import(block, "acme/x/shadow"))
  let with_options = "options(\n  warn_list: \"+unused\",\n)\n"
  let keyed = add_override(with_options, "acme/x/shadow")
  assert_true(keyed.contains("  overrides: [ \"acme/x/shadow\", ],\n"))
  assert_true(keyed.contains("  warn_list: \"+unused\",\n"))
  let with_array = "options(\n  overrides: [ \"other/shadow\" ],\n)\n"
  let extended = add_override(with_array, "acme/x/shadow")
  assert_true(extended.contains("\"other/shadow\", \"acme/x/shadow\","))
}

///|
test "render_scaffold points the gen rule at the library" {
  let scaffold = render_scaffold("PaiGack/moon_shadow", "..")
  assert_true(
    scaffold.contains(
      "command: \"moon run --target js --target-dir _build/gen ../gen/main.mbt -- $input $output\",",
    ),
  )
  assert_true(
    scaffold.contains("virtual(implement: \"PaiGack/moon_shadow/shadow\")"),
  )
  assert_true(
    scaffold.contains(
      "dev_build(rule: \"gen\", input: \"../moon.mod\", output: \"generated.mbt\")",
    ),
  )
}

///|
test "member_entries reads both spellings" {
  assert_eq(member_entries("members = [\n  \".\",\n  \"..\",\n]\n"), [".", ".."])
  assert_eq(member_entries("members = [ \".\", \"../lib\" ]"), [".", "../lib"])
  assert_eq(member_entries(""), [])
}

///|
test "is_our_scaffold recognises the marker" {
  assert_true(
    is_our_scaffold(
      "import {\n  \"PaiGack/moon_shadow/core\",\n}\n\nvirtual(implement: \"PaiGack/moon_shadow/shadow\")\n",
      "PaiGack/moon_shadow",
    ),
  )
  assert_false(
    is_our_scaffold(
      "virtual(implement: \"other/shadow\")", "PaiGack/moon_shadow",
    ),
  )
}

///|
test "init_module writes the scaffold, and only once" {
  let base = match @env.current_dir() {
    Some(dir) => dir
    None => "."
  }
  let root = join(base, "_init_wbtest_\{@env.now()}")
  let target = join(root, "consumer")
  let library = join(root, "libs/moon_shadow")
  create_dir(root)
  create_dir(target)
  write_text(
    join(target, "moon.mod"),
    "name = \"acme/test\"\n\nversion = \"0.1.0\"\n\npreferred_target = \"wasm-gc\"\n\nimport {\n  \"PaiGack/moon_shadow@0.1.2\",\n}\n",
  )
  write_text(
    join(target, "moon.pkg"),
    "import {\n  \"PaiGack/moon_shadow\",\n}\n",
  )
  let actions = init_module(library, "PaiGack/moon_shadow", target)
  assert_true(actions.length() > 0)
  let scaffold = must_read(join(join(target, "shadow"), "moon.pkg"))
  assert_true(
    scaffold.contains("virtual(implement: \"PaiGack/moon_shadow/shadow\")"),
  )
  assert_true(scaffold.contains("../libs/moon_shadow/gen/main.mbt"))
  let generated = must_read(join(join(target, "shadow"), "generated.mbt"))
  assert_true(generated.contains("name: \"acme/test\","))
  let manifest = must_read(join(target, "moon.pkg"))
  assert_true(has_import(manifest, "PaiGack/moon_shadow"))
  assert_true(has_import(manifest, "acme/test/shadow"))
  let work = must_read(join(target, "moon.work"))
  assert_true(has_member(work, target, library, "PaiGack/moon_shadow"))
  // A second run has nothing left to do.
  assert_eq(init_module(library, "PaiGack/moon_shadow", target), [])
  remove_tree(root)
}
