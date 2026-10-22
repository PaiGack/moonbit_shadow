# moon_shadow

Read a MoonBit module's own `moon.mod` metadata at **runtime**, without
shipping `moon.mod` and without touching the filesystem.

```moonbit nocheck
let info = @moon_shadow.current()
println(info.name)                          // "PaiGack/moon_shadow"
println(info.version)                       // "0.1.0"
println(info.long_version())                // "PaiGack/moon_shadow@0.1.0"
println(info.dep("moonbitlang/moon_config")) // Some(...)
```

## Using it in your own module

1. Depend on the published package:

```
moon add PaiGack/moon_shadow
```

2. Create a `shadow` package that implements the virtual package and keeps
   the implementation fresh from your `moon.mod`. One file, `shadow/moon.pkg`:

```
import {
  "PaiGack/moon_shadow/core",
}

virtual(implement: "PaiGack/moon_shadow/shadow")

rule(
  name: "gen",
  command: "moon run --target js --target-dir _build/gen .mooncakes/PaiGack/moon_shadow/gen/main.mbt -- \"$input\" \"$output\"",
)

dev_build(rule: "gen", input: "../moon.mod", output: "generated.mbt")
```

   The `gen` rule runs on every `moon check` / `moon build` / `moon run` — release
   builds included, pre-build rules are not debug-only — and writes
   `shadow/generated.mbt` from your `moon.mod`. It runs the generator
   straight out of `.mooncakes`, where `moon add` stages the dependency, so
   nothing has to be checked out beside your module; the separate
   `--target-dir` keeps the generator's own build artifacts out of the main
   `_build`. Swap `--target js` for `--target native` if you would rather not
   need `node` on the machine.

3. Point the packages that read the metadata at your implementation — the
   import, plus the override, in every `moon.pkg` whose build reaches
   `@moon_shadow.current()`:

```
import {
  "PaiGack/moon_shadow",
}

options(
  overrides: [ "your/module/shadow" ],
)
```

4. Run `moon check` once and you are done. From then on every build
   regenerates `shadow/generated.mbt` whenever `moon.mod` changes, and
   `@moon_shadow.current()` reports your module's metadata.

   Committing `shadow/generated.mbt` is cheap insurance: a clone that does not
   touch `moon.mod` keeps building even if the rule cannot run.

`moon_shadow_example/` is this setup, end to end.

## How it works

`moon.mod` is read once, at build time, and the values are compiled into the
artifact:

```
moon.mod --(gen rule)--> shadow/generated.mbt --(compile)--> current()
```

At runtime there is no file I/O, no `git` and no environment sniffing — just
struct field reads.

The metadata crosses the build boundary through the virtual package
`PaiGack/moon_shadow/shadow`, which exposes a single accessor:

```moonbit nocheck
pub fn module_info() -> @core.ModuleInfo
```

The `shadow` package ships a default implementation generated from *this*
module's `moon.mod`. A consumer points `options(overrides: [...])` at its own
implementation — the one generated from *its* `moon.mod` — and `current()`
starts reporting that module's metadata instead.

The `moon.mod` DSL is parsed by
[`moonbitlang/moon_config`](https://mooncakes.io/docs/moonbitlang/moon_config);
there is no hand-written parser here, so diagnostics for duplicate or unknown
keys come along for free.

## API

| Name | Description |
|---|---|
| `current()` | `ModuleInfo` of the module that was built |
| `ModuleInfo::dep` | look a dependency up by module name |
| `ModuleInfo::long_version` | `"name@version"`, the shape `moon add` takes |
| `ModuleInfo::to_long_version_string` | `"name version description"`, for `--version` output |
| fields | `name` `version` `description` `license` `repository` `readme` `keywords` `preferred_target` `supported_targets` `deps` |

## Repo layout

```
core/                ModuleInfo / Dependency, moon_config parsing, codegen
gen/                 the generator executable, moon.mod -> implementation
shadow/              virtual package + its generated default, gen rule
moon_shadow.mbt      the public API: current()
moon_shadow_example/ a consumer module, exactly the setup above
```

## Behaviour worth knowing

These come from how `moon` handles virtual packages and pre-build rules, and
they shape what this library can promise:

- **A `moon.pkg`-declared virtual package must expose functions, not values.**
  `moon` type-checks a virtual package's implementations against `pkg.mbti`, and
  a `pub let` of a type from another package fails that check even though it
  compiles in the implementing package. Hence `module_info()` rather than
  `module_info`.
- **`current()` describes whoever provided the implementation**, not whoever
  called it. `moon_shadow_example/` shows both sides: without an override you
  get the library's baked-in values, with one you get your own.
- **A module cannot override its own virtual package.** That is why the example
  is a separate module rather than another package inside `moon_shadow`.
- **A dependency from the registry never runs build rules.** MoonBit skips a
  dependency's pre-build steps when it is consumed from the registry, so this
  library cannot set your module up for you: the `shadow` package above is
  yours to create, and the `gen` rule inside it is what keeps
  `generated.mbt` fresh. What the library ships in `shadow/` is only the
  default implementation for consumers who never override.
- **`overrides` is per-package.** Every package whose build reaches the virtual
  package needs its own `options(overrides: [...])` — hence the example carries
  one in both its root package and `cmd/main`.
- **The `gen` rule reaches the generator through `.mooncakes`**, moon's staging
  layout for registry dependencies — the only copy of the library a registry
  consumer has on disk, and the path carries no version, so upgrades keep it.
  It is an internal layout: if a future moon moves it, the rule fails with
  `No such file or directory` the next time it runs — on any build, release
  included, because pre-build rules are not debug-only. Committing
  `generated.mbt` limits the damage to clones that go on to edit `moon.mod`.
- **Escapes are decoded once.** `moon_config` returns string literals in their
  raw source form (`"a \"b\""` yields `a \"b\"`), so `core` unescapes before
  re-emitting them; otherwise every regeneration would double the backslashes.
