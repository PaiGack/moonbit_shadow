#!/bin/sh
# 由 dev_build 调用：用已构建好的生成器刷新 module_info.mbt。
#
# 这里不能再调 moon（外层 moon 持有 `_build/.moon-lock`，嵌套会死锁），
# 所以生成器缺失时保持已有生成物不动，只提示一句。
set -e
input="$1"
output="$2"
gen="$(dirname "$0")/../_build/js/debug/build/nrzhangsan/moon_shadow/modinfo_gen/modinfo_gen.js"
if [ ! -f "$gen" ]; then
  echo "moon_shadow: 生成器未构建，保留现有 $output（先跑 moon build modinfo_gen --target js）" >&2
  exit 0
fi
node "$gen" "$input" "$output"
