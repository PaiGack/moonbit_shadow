# moon_shadow

Read a MoonBit module's own `moon.mod` metadata at **runtime**, without
shipping `moon.mod` and without touching the filesystem.

```moonbit nocheck
let info = @moon_shadow.current()
println(info.name)                          // "nrzhangsan/moon_shadow"
println(info.version)                       // "0.1.0"
println(info.long_version())                // "nrzhangsan/moon_shadow@0.1.0"
println(info.dep("moonbitlang/moon_config")) // Some(...)
```

## How it works

`moon.mod` is read once, at build time, and the values are compiled into the
artifact:

```
moon.mod --(gen rule)--> shadow/generated.mbt --(compile)--> current()
```

At runtime there is no file I/O, no `git` and no environment sniffing — just
struct field reads.

The metadata crosses the build boundary through the virtual package
`nrzhangsan/moon_shadow/shadow`, which exposes a single accessor:

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
core/                ModuleInfo / Dependency, `moon_config` parsing, codegen
gen/                 the generator executable, `moon.mod` -> implementation
shadow/              virtual package + its generated default, gen rule
moon_shadow.mbt      the public API: current()
moon_shadow_example/ a consumer module, with its own moon.work workspace
```

## Using it in your own module

1. Depend on `nrzhangsan/moon_shadow`.
2. Copy `moon_shadow_example/shadow_impl/` into your module and swap the module
   name in `moon.pkg`.
3. Point the packages that need the metadata at it:

```moonbit nocheck
options(
  overrides: [ "your/module/shadow_impl" ],
)

rule(
  name: "gen",
  command: "moon run --target js --target-dir _build/gen <path-to>/moon_shadow/gen/main.mbt -- $input $output",
)
dev_build(rule: "gen", input: "../moon.mod", output: "generated.mbt")
```

The command runs in your module root, and `$input` / `$output` are paths
relative to it. `gen/main.mbt` is run as a standalone file, so your module does
not need a dependency on it — only a path. Keep it in a `moon.work` beside the
library, as `moon_shadow_example/` does, and that path stays a plain `../`.

4. Run `moon check` once and commit `shadow_impl/generated.mbt`. From then on
   `moon check` / `moon run` regenerate it whenever `moon.mod` changes.

`moon_shadow_example/` is exactly this setup, end to end.

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
- **Downstream modules never run build rules.** Implementations are committed;
  after editing `moon.mod`, run `moon check` and commit the result. CI fails
  with a diff if you forget.
- **Escapes are decoded once.** `moon_config` returns string literals in their
  raw source form (`"a \"b\""` yields `a \"b\"`), so `core` unescapes before
  re-emitting them; otherwise every regeneration would double the backslashes.
