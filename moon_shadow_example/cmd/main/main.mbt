///|
fn main {
  let info = @moon_shadow.current()
  println("name:     \{info.name}")
  println("version:  \{info.version}")
  println("license:  \{info.license}")
  println("describe: \{@moon_shadow_example.describe()}")
  let git = @moon_shadow.git()
  println("git:")
  println("  available:  \{git.available}")
  println("  branch:     \{git.branch}")
  println("  describe:   \{git.describe}")
  println("  commit:     \{git.commit}")
  println("  dirty:      \{git.dirty}")
  println("  version:    \{@moon_shadow_example.git_describe()}")
  let build = @moon_shadow.build()
  println("build:")
  println("  describe:   \{@moon_shadow_example.build_describe()}")
  println("  moon:       \{build.moon()}")
  println("  moonc:      \{build.moonc()}")
  println("  profile:    \{build.profile}")
  println("  target:     \{build.target}")
  println("deps:")
  for dep in info.deps {
    println("  \{dep.name} = \{dep.version}")
  }
}
