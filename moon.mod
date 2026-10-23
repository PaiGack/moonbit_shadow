// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html

name = "PaiGack/moon_shadow"

version = "0.3.1"

readme = "README.mbt.md"

repository = "https://github.com/PaiGack/moonbit_shadow"

license = "Apache-2.0"

keywords = [ "shadow", "build-info", "metadata", "git-info" ]

preferred_target = "wasm-gc"

description = "Read a MoonBit module's own moon.mod and git metadata at runtime, baked in at build time."

import {
  "moonbitlang/async@0.22.5",
  "moonbitlang/moon_config@0.4.5",
  "moonbitlang/x@0.5.6",
}
