///|
fn main {
  let info = @modinfo.current()
  println(@moon_shadow_example.describe())
  println("license: \{info.license}")
  println("deps:")
  for dep in info.deps {
    println("  \{dep.name} = \{dep.version}")
  }
}
