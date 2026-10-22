///|
test "parse moon.mod metadata and deps" {
  let source =
    #|name = "acme/demo"
    #|version = "1.2.3"
    #|description = "demo module"
    #|license = "MIT"
    #|repository = "https://example.com/acme/demo"
    #|readme = "README.md"
    #|keywords = ["demo", "test"]
    #|preferred_target = "native"
    #|supported_targets = ["js", "native"]
    #|import {
    #|  "moonbitlang/x@0.4.6",
    #|  "moonbitlang/moon_config@0.4.4",
    #|}
    #|
  let parsed = @mooninfo.parse_moon_mod(source)
  assert_eq(parsed.errors, [])
  let info = parsed.info
  assert_eq(info.name, "acme/demo")
  assert_eq(info.version, "1.2.3")
  assert_eq(info.description, "demo module")
  assert_eq(info.license, "MIT")
  assert_eq(info.repository, "https://example.com/acme/demo")
  assert_eq(info.readme, "README.md")
  assert_eq(info.keywords, ["demo", "test"])
  assert_eq(info.preferred_target, "native")
  assert_eq(info.supported_targets, ["js", "native"])
  assert_eq(info.deps, [
    { name: "moonbitlang/x", version: "0.4.6", },
    { name: "moonbitlang/moon_config", version: "0.4.4", },
  ])
}

///|
test "missing fields stay empty" {
  let parsed = @mooninfo.parse_moon_mod("name = \"acme/min\"\n")
  assert_eq(parsed.errors, [])
  assert_eq(parsed.info.name, "acme/min")
  assert_eq(parsed.info.version, "")
  assert_eq(parsed.info.keywords, [])
  assert_eq(parsed.info.deps, [])
}

///|
test "diagnostics come from moon_config" {
  let parsed = @mooninfo.parse_moon_mod(
    "name = \"a/one\"\nname = \"a/two\"\nbogus = 1\n",
  )
  assert_eq(parsed.info.name, "a/one")
  assert_eq(parsed.errors.length(), 2)
}

///|
test "options style keys are flattened" {
  let parsed = @mooninfo.parse_moon_mod(
    "name = \"acme/opt\"\noptions(preferred_target: \"js\")\n",
  )
  assert_eq(parsed.errors, [])
  assert_eq(parsed.info.preferred_target, "js")
}

///|
test "escapes are decoded before they reach ModuleInfo" {
  let source = "name = \"acme/demo\"\n" +
    "description = \"a \\\"quoted\\\" thing\"\n" +
    "keywords = [\"a\\\"b\"]\n"
  let info = @mooninfo.parse_moon_mod(source).info
  assert_eq(info.description, "a \"quoted\" thing")
  assert_eq(info.keywords, ["a\"b"])
}
