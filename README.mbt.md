# moon_shadow

存储在 **MoonBit** 项目中的构建时间信息。

允许您在运行时访问构建过程和环境的属性，包括：

- `moon.mod` 信息，比如项目版本 依赖信息
- `git` 信息，比如生成构建工件的提交
- 编译中使用了哪个版本的 `Moonbit` 工具链（`moon` / `moonc`）
- 构建变体，`debug` 还是 `release`，以及编译到哪个 target
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
  "PaiGack/moon_shadow/buildinfo",
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

let build = @moon_shadow.build()
println(build.moon())                       // "moon 0.1.20261020"
println(build.moonc())                      // "moonc v0.10.16+b1a0e846e"
println(build.profile)                      // "debug" / "release"
println(build.target)                       // "wasm-gc" / "js" / "native"
```

## 仓库结构

```
mooninfo/            ModuleInfo / Dependency、moon_config 解析、moon.mod 侧渲染
gitinfo/             公开元信息 API：GitInfo 类型、版本字符串格式，
                     以及 RepoInfo -> GitInfo 的收口
gitx/gitz/core/      底层 Git 实现：SHA-1、inflate
gitx/gitz/repo/      直接读 .git 的那一层（不依赖 git 命令）：仓库发现与解析、
                     .git 布局、HEAD、refs、commit 对象、index、仓库状态
gitx/gitcli/         另一半：调用 git 命令采集同一份仓库信息
buildinfo/           BuildInfo / ToolchainInfo 类型，profile 与 target 的
                     targets 选择，以及虚拟包实现文件的渲染
gen/                 生成器可执行文件：读 moon.mod，先问 gitx/gitcli，
                     失败回退 gitx/gitz/repo，写出实现文件
shadow/              虚拟包及其生成的默认实现、gen 规则
moon_shadow.mbt      公共 API：current()、git()、build()
moon_shadow_example/ 一个使用者模块，即上述配置的完整示例
```

## 工作原理

`moon.mod`、git 状态、工具链版本在构建时各被读取一次，值随后被编译进产物。
运行时没有文件 I/O、没有 `git`、没有环境变量嗅探——只有结构体字段读取。

元数据通过虚拟包 `PaiGack/moon_shadow/shadow` 跨越构建边界，它暴露三个访问
函数：

```moonbit nocheck
pub fn module_info() -> @PaiGack/moon_shadow/mooninfo.ModuleInfo
pub fn git_info() -> @PaiGack/moon_shadow/gitinfo.GitInfo
pub fn build_info() -> @PaiGack/moon_shadow/buildinfo.BuildInfo
```

三个类型都写**完整包路径**而不是别名：虚拟包的实现要按这份 `pkg.mbti` 检查，
而实现包自己的 `moon.pkg` 把这些包叫什么别名，使用者说了算。这些路径在
生成器里是常量，生成的代码与 `pkg.mbti` 因此总能对上。

工具链版本**不是**裸元组。生成器读到的是 `moon` / `moonc` 两个版本，但它写进
实现文件的是一个 `BuildInfo`：

```moonbit nocheck
///|
pub fn build_info() -> @PaiGack/moon_shadow/buildinfo.BuildInfo {
  @PaiGack/moon_shadow/buildinfo.BuildInfo::from_toolchain({
    moon_version: "0.1.20261020",
    moonc_version: "v0.10.16+b1a0e846e",
  })
}
```

`from_toolchain` 在实现包里补上 `profile` 和 `target`——它们是 `targets`
选中的文件，只有实现包自己编译时知道。生成器不需要把这两个再传一遍，调用方
也不用记住 `(String, String)` 里哪个是哪个：以后加一个字段（channel、host、
构建时间）是加字段，不是改签名。

`shadow` 包自带一份从*本*模块的 `moon.mod`、本仓库的 git、本机工具链生成的
默认实现。使用者通过 `options(overrides: [...])` 指向自己的实现——即从*它自己*
的 `moon.mod` 和*它自己*的 checkout 生成的那份——`current()` / `git()` /
`build()` 便会转而报告该模块的元数据和它自己的构建变体。采集规则在消费者模块里执行，cwd 是消费者的模块目录，
从那里往上找第一个 `.git` 正好落在消费者自己的仓库根上，这就是想要的语义。

- `moon.mod` 的 DSL 由 [`moonbitlang/moon_config`](https://mooncakes.io/docs/moonbitlang/moon_config)
解析
- `git` 相关信息有两条采集路径，`gen` 依次尝试：
  1. [`gitx/gitcli`](./gitx/gitcli/)：直接跑 `git`，交给 git 自己回答。能处理
     打包对象、浅克隆、`GIT_DIR` 等你不想自己实现的情况。
  2. [`gitx/gitz/repo`](./gitx/gitz/repo/)：不启动任何进程，直接读 `.git` 里的
     `HEAD`、refs、commit 对象和 index。git 命令不可用时才走这条；它脚下的
     SHA-1 与 inflate 在 [`gitx/gitz/core`](./gitx/gitz/core/)。
  [`gitinfo`](./gitinfo/) 只在上面两条之外收口：定义 `GitInfo`、把 `RepoInfo`
  收成 `GitInfo`，并对外给出稳定的版本字符串。

  生成器不判断平台：能不能启动进程，试一次就知道了。但「启动不了」和「跑了
  但说不」是两回事，`gen` 只在**前者**回退：
  - `git` 根本起不来（没装、`cwd` 不存在）→ `gitx/gitcli` 返回 `None`，回退读 `.git`；
  - `git` 起了但退出码非 0（`fatal: not a git repository`）→ 这是答案，直接
    `available = false`，不再回头读 `.git`。`.git` 就在同一个目录里，`git`
    说没有，读文件不会给出第二个结论，只会打出两行互相矛盾的话。

  两条路的产出是同一个 `GitInfo` 类型；`RepoInfo.reason`（`NoDotGit` /
  `HeadUnreadable` / `GitRefused` / `Found`）记下是哪一步得出的结论。

## 需要了解的行为

以下都源于 `moon` 处理虚拟包和 pre-build 规则的方式，它们决定了本库
能做出哪些承诺：

- **`moon.pkg` 声明的虚拟包必须暴露函数，不能是值。** `moon` 会用
  `pkg.mbti` 类型检查虚拟包的各个实现，而一个来自其他包类型的
  `pub let` 会通不过这个检查——尽管它在实现包里能编译。因此是
  `module_info()` 而不是 `module_info`。工具链版本也遵守这条：所以虚拟包给的是
  `build_info()`，一个 `BuildInfo`，而不是一对字符串。
- **`buildinfo` 不能 import `shadow`。** `shadow` 的 `pkg.mbti` 要用
  `buildinfo.BuildInfo` 描述返回值，于是 `shadow` → `buildinfo` 是一条固定
  的边；反过来让 `buildinfo` 去读虚拟包就是环，`moon` 会直接拒绝构建计划。
  所以版本值只以返回类型的形式跨越边界：`gen` 写出 `BuildInfo`，`buildinfo`
  定义它的形状，谁也不回头去问。
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
- **`git_info()` 不进 CI 比对。** 它记的是「跑生成器那次构建」的 commit、
  提交日期和 `dirty`，两份构建不可能一致：PR 的合并提交不等于作者生成时
  用的提交，CI 里的检出版本也不等于 `HEAD`。所以 CI 只比 `module_info()`
  （由 `moon.mod` 决定）和 `build_info()`（由工具链决定），`git_info()`
  整块跳过——见 `scripts/diff-generated.sh`。
