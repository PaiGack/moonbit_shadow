# moon_shadow

在**运行时**读取 MoonBit 模块自己的元数据——`moon.mod` 的字段，以及构建那次
checkout 的 git 状态。两者都在构建期采集一次、烘焙进产物，运行时没有文件
I/O、没有 git、没有环境变量嗅探。

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

## 为什么 git 信息不是运行时采集

你发布的软件跑在别人的电脑上：那台机器大概率没有 git、没有 `.git`，cwd 落在
哪里也不关你的事。运行时采集等于把不确定性外包给终端用户，最后只能拿到
`available = false`。想要稳定的 git 信息，只在**构建这台机器、这次 checkout**
上采集一次，然后编进产物。

`moon.mod` 也是同样的道理，所以两条链共用同一份生成物：

```
moon.mod ----(gen rule)---> shadow/generated.mbt --(compile)--> current()
git 命令 ----(gen rule)--->                       --(compile)--> git()
```

与运行时方案相比还有一个额外好处：烘焙进产物就是纯常量，`wasm-gc` /
`js` / `native` 一样能用，不需要为读 git 限制 target。

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
  "PaiGack/moon_shadow/gitinfo",
}

virtual(implement: "PaiGack/moon_shadow/shadow")

rule(
  name: "gen",
  command: "moon run --target-dir _build/gen .mooncakes/PaiGack/moon_shadow/gen/main.mbt -- \"$input\" \"$output\"",
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

3. 让读取元数据的包指向你的实现——在每一个构建路径会经过
   `@moon_shadow.current()` / `@moon_shadow.git()` 的 `moon.pkg` 里加上 import
   和 override：

```
import {
  "PaiGack/moon_shadow",
}

options(
  overrides: [ "your/module/shadow" ],
)
```

## 工作原理

`moon.mod` 和 git 状态在构建时各被读取一次，值随后被编译进产物。运行时没有
文件 I/O、没有 `git`、没有环境变量嗅探——只有结构体字段读取。

元数据通过虚拟包 `PaiGack/moon_shadow/shadow` 跨越构建边界，它暴露两个访问
函数：

```moonbit nocheck
pub fn module_info() -> @core.ModuleInfo
pub fn git_info() -> @gitinfo.GitInfo
```

`@gitinfo.GitInfo` 是别的包里的类型，`pkg.mbti` 里引用它没问题——只要虚拟包
自己的 `moon.pkg` 导入了 `gitinfo`。

`shadow` 包自带一份从*本*模块的 `moon.mod` 和本仓库的 git 生成的默认实现。
使用者通过 `options(overrides: [...])` 指向自己的实现——即从*它自己*的
`moon.mod` 和*它自己*的 checkout 生成的那份——`current()` / `git()` 便会转而
报告该模块的元数据。采集规则在消费者模块里执行，cwd 是消费者的模块目录，
`git rev-parse` 往上找正好落在消费者自己的仓库根上，这就是想要的语义。

`moon.mod` 的 DSL 由
[`moonbitlang/moon_config`](https://mooncakes.io/docs/moonbitlang/moon_config)
解析

## API

| 名称 | 说明 |
|---|---|
| `current()` | 被构建模块的 `ModuleInfo` |
| `git()` | 构建它的那次 checkout 的 `GitInfo` |
| `ModuleInfo::dep` | 按模块名查找依赖 |
| `ModuleInfo::long_version` | `"name@version"`，`moon add` 接受的格式 |
| `ModuleInfo::to_long_version_string` | `"name version description"`，用于 `--version` 输出 |
| `GitInfo::describe_version` | 分支 / tag / describe 里最具体的那个，脏时带 `-dirty` |
| `GitInfo::commit_version` | commit（可要短 hash），脏时带 `-dirty` |
| `GitInfo::to_version_string` | 上面两个拼起来；`available = false` 时是 `"unavailable"` |
| `GitInfo::is_dirty` | `available && dirty` |
| `ModuleInfo` 字段 | `name` `version` `description` `license` `repository` `readme` `keywords` `preferred_target` `supported_targets` `deps` |
| `GitInfo` 字段 | `available` `branch` `tag` `describe` `commit` `short_commit` `commit_date` `author` `email` `dirty` `ahead` `behind` |

## 仓库结构

```
core/                ModuleInfo / Dependency、moon_config 解析、moon.mod 侧渲染
gitinfo/             GitInfo 类型、"怎么把一段输出解释成字段"的纯逻辑
gen/                 生成器可执行文件：读 moon.mod、跑 git、写出实现文件
shadow/              虚拟包及其生成的默认实现、gen 规则
moon_shadow.mbt      公共 API：current()、git()
moon_shadow_example/ 一个使用者模块，即上述配置的完整示例
```

## 需要了解的行为

以下都源于 `moon` 处理虚拟包和 pre-build 规则的方式，它们决定了本库
能做出哪些承诺：

- **`moon.pkg` 声明的虚拟包必须暴露函数，不能是值。** `moon` 会用
  `pkg.mbti` 类型检查虚拟包的各个实现，而一个来自其他包类型的
  `pub let` 会通不过这个检查——尽管它在实现包里能编译。因此是
  `module_info()` 而不是 `module_info`。
- **`current()` / `git()` 描述的是提供实现的人**，不是调用它的人。
  `moon_shadow_example/` 展示了两种情况：没有 override 时得到库
  baked-in 的值，有 override 时得到你自己的。
- **模块不能 override 自己的虚拟包。** 这就是示例之所以是独立模块、
  而不是 `moon_shadow` 内另一个包的原因。
- **来自 registry 的依赖不会运行构建规则。** MoonBit 会跳过 registry
  依赖被消费时的 pre-build 步骤，所以本库无法替你完成模块的配置：
  上面的 `shadow` 包需要你自己创建，里面的 `gen` 规则负责让
  `generated.mbt` 保持新鲜。库在 `shadow/` 里附带的只是给从不
  override 的使用者的默认实现——也就是说 `moon add` 完，`git()` 拿到的是
  *本库*烘焙进去的值，不是你的仓库。想要自己仓库的 git 信息，就得自己建
  `shadow` 包和 `gen` 规则。
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
- **`dirty` 只看已跟踪文件。** `git status --porcelain --untracked-files=no`。
  `generated.mbt` 是入库的，用默认行为的话「生成」这个动作本身就会让工作区
  变脏，然后永远是脏的。
- **git 不在规则输入里。** `dev_build(input: "../moon.mod")` 只看 `moon.mod`，
  这是有意的：否则每次 commit 都会让生成物失效、触发重编。代价是 git 变了
  不会自动重新生成——想让 `git_info()` 跟上新 commit，`moon clean` 一下让
  `generated.mbt` 重新生成即可。发布构建本来就在全新的 checkout 上跑，不受
  影响。
- **生成内容对同一份输入完全确定**（不写时间戳、不写随机值），所以
  「重新生成 = 无 diff」，CI 里那句 `git diff --exit-code` 才有意义。
- **非 git 环境不让构建失败。** 不是仓库、没装 git，生成器照常写文件，
  `available = false`、其余字段为空串 / 0，并在 stdout 上说一句。
- **所有 git 调用带 `GIT_OPTIONAL_LOCKS=0`**，避免抢 `index.lock` 卡住用户
  自己的 `git commit`。
- **转义只解码一次。** `moon_config` 返回的字符串字面量是源码原始
  形式（`"a \"b\""` 得到 `a \"b\"`），因此 `core` 会在重新生成前
  做一次反转义；否则每次重新生成都会让反斜杠翻倍。
