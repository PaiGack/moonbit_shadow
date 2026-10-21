// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html

name = "nrzhangsan/moon_shadow"

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://cnb.cool/nrzhangsan/moon_shadow"

license = "Apache-2.0"

keywords = [ "metadata", "build-info", "moon.mod" ]

preferred_target = "wasm-gc"

description = "Build-time module metadata for MoonBit, in the spirit of shadow-rs"

import {
  "moonbitlang/moon_config@0.4.4",
  "moonbitlang/x@0.5.6",
}

rule(name: "modinfo", command: "sh scripts/gen_modinfo.sh $input $output")
