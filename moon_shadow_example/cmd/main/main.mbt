///|
fn main {
  let info = @moon_shadow.current()
  println("name:     \{info.name}")
  println("version:  \{info.version}")
  println("license:  \{info.license}")
  println("describe: \{@moon_shadow_example.describe()}")
  println("deps:")
  for dep in info.deps {
    println("  \{dep.name} = \{dep.version}")
  }
}
