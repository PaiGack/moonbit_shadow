# nrzhangsan/moon_shadow

MoonBit 模块的构建期元信息，思路对标 [shadow-rs](https://github.com/baoyachi/shadow-rs)：
把 `moon.mod` 里的 name / version / deps 等编进产物，运行时不用再读文件。

## 用法

```moonbit
fn main {
  let info = @modinfo.current()
  println("${info.name} ${info.version}")
  println("license: ${info.license}")
  for dep in info.deps {
    println("  ${dep.name} = ${dep.version}")
  }
}
```

`moon.pkg` 里加上：

```text
import {
  "nrzhangsan/moon_shadow/modinfo",
}
```

运行产物时不需要 `moon.mod`：元信息是编译期常量，随二进制走。

## 结构

| 包 | 作用 |
|---|---|
| `modinfo_types` | `ModuleInfo` / `Dependency` 数据结构 |
| `modfile` | 用 `moonbitlang/moon_config` 解析 `moon.mod` 源码（纯函数，好测） |
| `modinfo` | 虚拟包，`current()` 返回编进产物的元信息 |
| `modinfo_gen_codegen` | `ModuleInfo` → `module_info.mbt` 源码渲染（纯函数） |
| `modinfo_gen` | 命令行：读 `moon.mod` 写 `module_info.mbt` |
| `moon_shadow_example` | 独立示例模块，演示怎么用 |

## 生成物怎么更新

`modinfo/module_info.mbt` 是生成文件，**必须入库**。下游用户构建时不会跑预构建脚本，
compiler 直接编译这份文件。

刷新流程（本地和 CI 都一样）：

```sh
moon build modinfo_gen --target js   # 构建生成器，只需一次
moon check --target wasm-gc          # 触发 dev_build，脚本用生成器重写 module_info.mbt
git diff --exit-code modinfo/module_info.mbt
```

`dev_build` 里调用的 `scripts/gen_modinfo.sh` 不会嵌套调用 `moon`——外层 `moon`
进程正持有 `_build/.moon-lock`，嵌套会死锁。脚本只负责把已构建好的生成器跑起来。

## 已知边界

- `moon_config` 会把 `preferred_target = ...` 规范成 `preferred-target`，但
  `options(preferred_target: ...)` 里的下划线写法保持原样，解析层两种都认。
- 虚拟包的 `pkg.mbti` 里写不了顶层 `let`，所以生成物用
  `warnings = "-missing_definition"` 压掉「不在 mbti 里」的提示。
- example 用的是主模块编进去的元信息；要拿自己的元信息，需要在 example 里也放一份
  `dev_build`，示例为了简洁没这么做。
