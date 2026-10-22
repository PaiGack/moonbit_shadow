# moon_shadow

在**运行时**读取 MoonBit 模块自身的 `moon.mod` 元数据——既不需要随包分发
`moon.mod`，也不需要访问文件系统。

```moonbit nocheck
let info = @moon_shadow.current()
println(info.name)                          // "PaiGack/moon_shadow"
println(info.version)                       // "0.1.0"
println(info.long_version())                // "PaiGack/moon_shadow@0.1.0"
println(info.dep("moonbitlang/moon_config")) // Some(...)
```

## 在自己的模块中使用

1. 依赖已发布的包：

```
moon add PaiGack/moon_shadow
```

2. 创建一个 `shadow` 包来实现该虚拟包，并让实现始终与你的 `moon.mod`
   保持同步。只需要一个文件，`shadow/moon.pkg`：

```
import {
  "PaiGack/moon_shadow/core",
}

virtual(implement: "PaiGack/moon_shadow/shadow")

rule(
  name: "gen",
  command: "moon run --target-dir _build/gen .mooncakes/PaiGack/moon_shadow/gen/main.mbt -- \"$input\" \"$output\"",
)

dev_build(rule: "gen", input: "../moon.mod", output: "generated.mbt")
```

   `gen` 规则在每次 `moon check` / `moon build` / `moon run` 时都会运行——
   包括 release 构建，pre-build 规则并非 debug 专用——它会用你的
   `moon.mod` 生成 `shadow/generated.mbt`。生成器直接从 `.mooncakes`
   运行，`moon add` 会把依赖暂存在那里，因此模块旁边不需要检出任何
   东西；单独的 `--target-dir` 让生成器自己的构建产物不进入主 `_build`。

   也可以不手写：把 `moon_shadow_example/shadow/` 整个复制到你的模块里。

3. 让读取元数据的包指向你的实现——在每一个构建路径会经过
   `@moon_shadow.current()` 的 `moon.pkg` 里加上 import 和 override：

```
import {
  "PaiGack/moon_shadow",
}

options(
  overrides: [ "your/module/shadow" ],
)
```

## 工作原理

`moon.mod` 在构建时被读取一次，值随后被编译进产物：

```
moon.mod --(gen rule)--> shadow/generated.mbt --(compile)--> current()
```

运行时没有文件 I/O、没有 `git`、没有环境变量嗅探——只有结构体字段读取。

元数据通过虚拟包 `PaiGack/moon_shadow/shadow` 跨越构建边界，它只暴露
一个访问函数：

```moonbit nocheck
pub fn module_info() -> @core.ModuleInfo
```

`shadow` 包自带一份从*本*模块的 `moon.mod` 生成的默认实现。使用者通过
`options(overrides: [...])` 指向自己的实现——即从*它自己*的 `moon.mod`
生成的那份——`current()` 便会转而报告该模块的元数据。

`moon.mod` 的 DSL 由
[`moonbitlang/moon_config`](https://mooncakes.io/docs/moonbitlang/moon_config)
解析

## API

| 名称 | 说明 |
|---|---|
| `current()` | 被构建模块的 `ModuleInfo` |
| `ModuleInfo::dep` | 按模块名查找依赖 |
| `ModuleInfo::long_version` | `"name@version"`，`moon add` 接受的格式 |
| `ModuleInfo::to_long_version_string` | `"name version description"`，用于 `--version` 输出 |
| 字段 | `name` `version` `description` `license` `repository` `readme` `keywords` `preferred_target` `supported_targets` `deps` |

## 仓库结构

```
core/                ModuleInfo / Dependency、moon_config 解析、代码生成
gen/                 生成器可执行文件，moon.mod -> 实现文件
shadow/              虚拟包及其生成的默认实现、gen 规则
moon_shadow.mbt      公共 API：current()
moon_shadow_example/ 一个使用者模块，即上述配置的完整示例
```

## 需要了解的行为

以下都源于 `moon` 处理虚拟包和 pre-build 规则的方式，它们决定了本库
能做出哪些承诺：

- **`moon.pkg` 声明的虚拟包必须暴露函数，不能是值。** `moon` 会用
  `pkg.mbti` 类型检查虚拟包的各个实现，而一个来自其他包类型的
  `pub let` 会通不过这个检查——尽管它在实现包里能编译。因此是
  `module_info()` 而不是 `module_info`。
- **`current()` 描述的是提供实现的人**，不是调用它的人。
  `moon_shadow_example/` 展示了两种情况：没有 override 时得到库
  baked-in 的值，有 override 时得到你自己的。
- **模块不能 override 自己的虚拟包。** 这就是示例之所以是独立模块、
  而不是 `moon_shadow` 内另一个包的原因。
- **来自 registry 的依赖不会运行构建规则。** MoonBit 会跳过 registry
  依赖被消费时的 pre-build 步骤，所以本库无法替你完成模块的配置：
  上面的 `shadow` 包需要你自己创建，里面的 `gen` 规则负责让
  `generated.mbt` 保持新鲜。库在 `shadow/` 里附带的只是给从不
  override 的使用者的默认实现。
- **`overrides` 是 per-package 的。** 每个构建路径会到达虚拟包的包
  都需要自己的 `options(overrides: [...])`——因此示例在根包和
  `cmd/main` 里各写了一份。
- **`gen` 规则通过 `.mooncakes` 找到生成器**，即 moon 为 registry
  依赖准备的暂存布局——registry 使用者磁盘上本库的唯一副本，且路径
  不含版本号，升级不受影响。它是内部布局：如果未来的 moon 改动了它，
  规则下次运行时会以 `No such file or directory` 失败——在任何构建上，
  包括 release，因为 pre-build 规则并非 debug 专用。提交
  `generated.mbt` 可以把损失限制在「克隆之后又去改 `moon.mod`」
  的场景。
- **转义只解码一次。** `moon_config` 返回的字符串字面量是源码原始
  形式（`"a \"b\""` 得到 `a \"b\"`），因此 `core` 会在重新生成前
  做一次反转义；否则每次重新生成都会让反斜杠翻倍。
