# moon_shadow_example

A module that reads **its own** `moon.mod` at runtime through `moon_shadow`.

```moonbit nocheck
let info = @moon_shadow.current()
println(info.name)           // "username/moon_shadow_example"
println(info.version)        // "0.2.0"
```

Run it:

```
moon run --target js cmd/main
```

## How the metadata gets in

`moon_shadow` reads metadata through the virtual package
`username/moon_shadow/shadow`. This module implements it in `shadow_impl/`,
and `moon.pkg` points `overrides` at that package:

```moonbit nocheck
options(
  overrides: [ "username/moon_shadow_example/shadow_impl" ],
)
```

`shadow_impl/generated.mbt` is committed, so a clean clone needs no extra
step. Keep it in sync with `moon.mod` when the version or description change.
