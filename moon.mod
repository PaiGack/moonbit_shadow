// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html

name = "PaiGack/moon_shadow"

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://github.com/PaiGack/moonbit_shadow"

license = "Apache-2.0"

keywords = [ "shadow", "build-info", "metadata" ]

preferred_target = "wasm-gc"

description = "Read a MoonBit module's own moon.mod metadata at runtime, baked in at build time."

import {
  "moonbitlang/moon_config@0.4.4",
  "moonbitlang/x@0.5.6",
}
