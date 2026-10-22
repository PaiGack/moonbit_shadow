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

1. Depend on `PaiGack/moon_shadow`, with the library in a `moon.work`
   beside your module — the setup `moon_shadow_example/` shows:

```
moon add PaiGack/moon_shadow
```

2. Run `moon check`. The `init` rule in the library's `shadow/moon.pkg`
   discovers your module — it looks for the `moon.mod` files near the library
   that import it — and writes everything the manual setup used to ask for:

```
moon_shadow: initialized /path/to/your/module
  moon.work: added member ..
  shadow/moon.pkg: created
  shadow/generated.mbt: created
  moon.pkg: added import PaiGack/moon_shadow
  moon.pkg: added overrides your/module/shadow
```

3. Run `moon check` once more and you are done. From then on `moon check` /
   `moon run` regenerate `shadow/generated.mbt` whenever `moon.mod` changes,
   and `@moon_shadow.current()` reports your module's metadata.

To set one module up by hand, point the `init` package at it explicitly —
the same program the rule runs, with the directory as its argument:

```moonbit nocheck
moon run --target js --target-dir _build/init <path-to>/moon_shadow/init -- /path/to/your/module
```

Run it from the `moon_shadow` module root. It prints what it changed, is
idempotent, and leaves an already set-up module untouched.

### What the scaffold contains

`init` writes two files and patches two, which is the whole manual setup:

`shadow/moon.pkg` — implement the virtual package, and keep the
implementation fresh from your `moon.mod`:

```moonbit nocheck
import {
  "PaiGack/moon_shadow/core",
}

virtual(implement: "PaiGack/moon_shadow/shadow")

rule(
  name: "gen",
  command: "moon run --target js --target-dir _build/gen <path-to>/moon_shadow/gen/main.mbt -- $input $output",
)
dev_build(rule: "gen", input: "../moon.mod", output: "generated.mbt")
```

The command runs in your module root, and `$input` / `$output` are paths
relative to it. `gen/main.mbt` is run as a standalone file, so your module does
not need a dependency on it — only a path.

`shadow/generated.mbt` — rendered from your `moon.mod`, committed.

Your root `moon.pkg` — the import, plus the override that points the packages
reading the metadata at your implementation:

```moonbit nocheck
options(
  overrides: [ "your/module/shadow" ],
)
```

Your `moon.work` — the library as a member, so the `gen` command above can
reach it.

`moon_shadow_example/` is exactly this setup, end to end.


## How it works

`moon.mod` is read once, at build time, and the values are compiled into the
artifact:

```
moon.mod --(gen rule)--> shadow/generated.mbt --(compile)--> current()
```

At runtime there is no file I/O, no `git` and no environment sniffing — just
struct field reads.

The same build boundary is crossed the other way by `init`: a `dev_build` rule
in `shadow/moon.pkg` runs the `init` package on every `moon check` /
`moon build` / `moon run`, and writes the scaffold a consumer needs into any
module nearby that depends on this one:

```
consumer moon.mod --(init rule)--> shadow/ scaffold + overrides in moon.pkg
```

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
core/                ModuleInfo / Dependency, `moon_config` parsing, codegen
gen/                 the generator executable, `moon.mod` -> implementation
init/                the one-command setup, writes a consumer's shadow scaffold
shadow/              virtual package + its generated default, gen + init rules
moon_shadow.mbt      the public API: current()
moon_shadow_example/ a consumer module, with its own moon.work workspace
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
  dependency's pre-build steps when it is consumed from `.mooncakes`, so
  published implementations are committed: after editing `moon.mod`, run
  `moon check` and commit the result. CI fails with a diff if you forget.
- **A workspace member's rules do run.** A library listed in a consumer's
  `moon.work` is built as part of that consumer's build, rules included — which
  is what `init` relies on to set a consumer up unattended, and why the
  `moon.work` setup above is the supported one.
- **Escapes are decoded once.** `moon_config` returns string literals in their
  raw source form (`"a \"b\""` yields `a \"b\"`), so `core` unescapes before
  re-emitting them; otherwise every regeneration would double the backslashes.
