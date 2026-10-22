///|
fn main {
  let info = @moon_shadow.current()
  println("name:    \{info.name}")
  println("version: \{info.version}")
  println("license: \{info.license}")
  println("tag:     \{info.long_version()}")
  println("describe: \{@example.describe()}")
}
