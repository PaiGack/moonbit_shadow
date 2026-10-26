#!/bin/sh
# Compare committed `generated.mbt` files with a fresh `moon check` output.
#
# `git_info()` is not checked. It is a photo of the checkout that ran the
# generator — commit id, commit date, `dirty` — so it cannot be the same in two
# builds, and a build must not go red over it. Everything else in the file is a
# function of `moon.mod` and the toolchain, and is compared byte for byte.
#
# The banner comment is the marker: it is the only place the generator spells
# `git checkout this module was built in`, and the block that follows it ends at
# the next `///|`. Drop those lines from both sides and diff the rest.
#
# usage: scripts/diff-generated.sh <stripped-committed> <stripped-fresh>
set -eu

strip() {
  awk '
    /git checkout this module was built in/ { skip = 1; next }
    skip && /^\/\/\/\|$/ { skip = 0; next }
    !skip
  ' "$1"
}

strip "$1" > /tmp/moon_shadow_want.mbt
strip "$2" > /tmp/moon_shadow_got.mbt
diff -u /tmp/moon_shadow_want.mbt /tmp/moon_shadow_got.mbt
