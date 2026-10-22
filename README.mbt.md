# moon_shadow

Read a MoonBit module's own `moon.mod` metadata at **runtime**, without
shipping `moon.mod` and without touching the filesystem.

```moonbit nocheck
let info = @moon_shadow.current()
println(info.name)           // "nrzhangsan/moon_shadow"
println(info.version)        // "0.1.0"
println(info.long_version()) // "nrzhangsan/moon_shadow@0.1.0"
```

## How it works

`moon.mod` is read once, at build time. A `dev_build` rule regenerates
`shadow/generated.mbt`, so the values are baked into the binary:

```
moon.mod --(gen rule)--> shadow/generated.mbt --(compile)--> current()
```

At runtime there is no file I/O, no `git` and no environment sniffing — just
struct field reads.

The metadata crosses the build boundary through the virtual package
`nrzhangsan/moon_shadow/shadow`. That indirection is what lets a *consumer*
supply its own values instead of the library's.

The `moon.mod` DSL itself is parsed by
[`moonbitlang/moon_config`](https://mooncakes.io/docs/moonbitlang/moon_config)
rather than by hand, so diagnostics for duplicate or unknown keys come for free.

## API

| Name | Description |
|---|---|
| `current()` | `ModuleInfo` of the module that pulled the library in |
| `ModuleInfo::long_version` | `"name@version"`, the shape `moon add` takes |
| fields | `name` `version` `description` `license` `repository` `readme` `keywords` `preferred_target` |

## Repo layout

```
.                    moon_shadow, the library
modfile/             parse_moon_mod: moon.mod source -> ModuleInfo + errors
shadow/              virtual package, its generated implementation, gen rule
gen/                 build-time generator, writes shadow/generated.mbt
moon_shadow_example/ a real consumer of the library
moon.work            workspace tying both modules together
```

## Behaviour worth knowing

These come from how `moon` handles virtual packages and pre-build rules, and
they shape what this library can promise:

- **The module that owns `moon.mod` must own the implementation.** A module
  cannot override its own virtual package, and a virtual package's `pkg.mbti`
  only accepts flat function declarations. That is why `shadow/` declares one
  `module_*` function per field instead of a struct with accessors.
- **`current()` describes whoever provided the implementation**, not whoever
  called it. `moon_shadow_example/` shows both sides: `describe()` goes through
  `modinfo` and reports the library's baked-in values, while `own_metadata()`
  imports the `shadow` virtual package directly and, with its
  `overrides: [ "nrzhangsan/moon_shadow_example/shadow_impl" ]`, gets its own
  `moon.mod` values.
- **Downstream modules never run build rules.** `shadow/generated.mbt` is
  committed, and consumers commit their own generated implementation too. After
  changing `moon.mod`, run `moon check` and commit the result.
- **Regeneration needs one command.** `moon build` / `moon check` run the rule;
  if the output is missing, the very first run can pass before the file exists,
  so run it twice on a fresh clone.
- **The example's implementation has no build rule of its own.** `shadow_impl/`
  sits inside a workspace member, and a pre-build rule there runs with the
  example as cwd, where the `gen` package is not reachable. Refresh it by hand:
  `moon run --target js --target-dir _build/gen gen -- moon_shadow_example/moon.mod moon_shadow_example/shadow_impl/generated.mbt`.
- **`preferred_target` is normalized.** `moon_config` reports it as
  `preferred-target`, while `options(preferred_target: ...)` keeps the
  underscore form; the parser accepts both.
