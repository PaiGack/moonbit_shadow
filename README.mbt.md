# moon_shadow

存储在 **MoonBit** 项目中的构建时间信息。

允许您在运行时访问构建过程和环境的属性，包括：

- `moon.mod` 信息，比如项目版本 依赖信息
- `git` 信息，比如生成构建工件的提交
- 编译中使用了哪个版本的 `Moonbit` 工具链
- 构建变体，例如： 或 `debug` `release`
- 还有更多...

## 快速上手

1. 添加依赖：

```
moon add PaiGack/moon_shadow
```

2. 创建一个 `shadow` 包来实现该虚拟包，并让实现始终与你的 `moon.mod`
   保持同步。只需要一个文件，`shadow/moon.pkg`：

```
import {
  "PaiGack/moon_shadow/mooninfo",
  "PaiGack/moon_shadow/gitinfo",
}

virtual(implement: "PaiGack/moon_shadow/shadow")

rule(
  name: "gen",
  command: "moon run --target native --target-dir _build/gen .mooncakes/PaiGack/moon_shadow/gen -- \"$input\" \"$output\"",
)

dev_build(rule: "gen", input: "../moon.mod", output: "generated.mbt")
```

   `gen` 规则在每次 `moon check` / `moon build` / `moon run` 时都会运行——
   包括 release 构建，pre-build 规则并非 debug 专用——它会读你的
   `moon.mod`、再看一眼当前 checkout 的 git，把两者写进
   `shadow/generated.mbt`。生成器直接从 `.mooncakes` 运行，`moon add`
   会把依赖暂存在那里，因此模块旁边不需要检出任何东西；单独的
   `--target-dir` 让生成器自己的构建产物不进入主 `_build`。

   也可以不手写：把 `moon_shadow_example/shadow/` 整个复制到你的模块里。

3. 让读取元数据的包指向你的实现——在每一个构建路径里加上 `import` 和 `override`：

```
import {
  "PaiGack/moon_shadow",
}

options(
  overrides: [ "your/module/shadow" ],
)
```

```moonbit nocheck
let info = @moon_shadow.current()
println(info.name)                          // "PaiGack/moon_shadow"
println(info.version)                       // "0.1.1"
println(info.long_version())                // "PaiGack/moon_shadow@0.1.1"
println(info.dep("moonbitlang/moon_config")) // Some(...)

let git = @moon_shadow.git()
println(git.branch)                         // "main"
println(git.to_version_string())            // "main-dirty 50a396b-dirty"
```

## 仓库结构

```
mooninfo/            ModuleInfo / Dependency、moon_config 解析、moon.mod 侧渲染
gitinfo/             GitInfo 类型，以及真正读 .git 的那一层：
                     仓库发现、refs、inflate、commit 对象、index、sha-1
gen/                 生成器可执行文件：读 moon.mod，调 gitinfo，写出实现文件
shadow/              虚拟包及其生成的默认实现、gen 规则
moon_shadow.mbt      公共 API：current()、git()
moon_shadow_example/ 一个使用者模块，即上述配置的完整示例
```

## 工作原理

`moon.mod` 和 git 状态在构建时各被读取一次，值随后被编译进产物。运行时没有
文件 I/O、没有 `git`、没有环境变量嗅探——只有结构体字段读取。

元数据通过虚拟包 `PaiGack/moon_shadow/shadow` 跨越构建边界，它暴露两个访问
函数：

```moonbit nocheck
pub fn module_info() -> @PaiGack/moon_shadow/mooninfo.ModuleInfo
pub fn git_info() -> @PaiGack/moon_shadow/gitinfo.GitInfo
```

两个类型都写**完整包路径**而不是别名：虚拟包的实现要按这份 `pkg.mbti` 检查，
而实现包自己的 `moon.pkg` 把这两个包叫什么别名，使用者说了算。这两个路径在
生成器里是常量，生成的代码与 `pkg.mbti` 因此总能对上。

`shadow` 包自带一份从*本*模块的 `moon.mod` 和本仓库的 git 生成的默认实现。
使用者通过 `options(overrides: [...])` 指向自己的实现——即从*它自己*的
`moon.mod` 和*它自己*的 checkout 生成的那份——`current()` / `git()` 便会转而
报告该模块的元数据。采集规则在消费者模块里执行，cwd 是消费者的模块目录，
从那里往上找第一个 `.git` 正好落在消费者自己的仓库根上，这就是想要的语义。

- `moon.mod` 的 DSL 由 [`moonbitlang/moon_config`](https://mooncakes.io/docs/moonbitlang/moon_config)
解析
- `git` 相关信息由 [`gitinfo`](./gitinfo/) 负责直接读取 `.git` 中的信息解析  

## 需要了解的行为

以下都源于 `moon` 处理虚拟包和 pre-build 规则的方式，它们决定了本库
能做出哪些承诺：

- **`moon.pkg` 声明的虚拟包必须暴露函数，不能是值。** `moon` 会用
  `pkg.mbti` 类型检查虚拟包的各个实现，而一个来自其他包类型的
  `pub let` 会通不过这个检查——尽管它在实现包里能编译。因此是
  `module_info()` 而不是 `module_info`。
- **模块不能 override 自己的虚拟包。** 这就是示例之所以是独立模块、
  而不是 `moon_shadow` 内另一个包的原因。
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
