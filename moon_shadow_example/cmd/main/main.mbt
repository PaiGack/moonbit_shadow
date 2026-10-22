///|
fn main {
  let info = @moon_shadow_info.current()
  println("name:     \{info.name}")
  println("version:  \{info.version}")
  println("license:  \{info.license}")
  println("describe: \{@example.describe()}")
  println("deps:")
  for dep in info.deps {
    println("  \{dep.name} = \{dep.version}")
  }
}
