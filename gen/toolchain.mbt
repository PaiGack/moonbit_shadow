///|
/// `moon` and `moonc` versions for the build that is running this generator.
///
/// Read once here and compiled in, for the usual reason: the machine running
/// the software has no toolchain, and may never have had one. A missing half is
/// reported as an empty string rather than skipped: the field is then visibly
/// wrong, and `gen` keeps writing a file instead of failing every build that
/// runs it — including the ones where nobody asked about the toolchain.
async fn collect_toolchain_info() -> @buildinfo.ToolchainInfo {
  let (status, stdout) = @process.collect_stdout(
    "moon",
    ["version", "--all"],
    no_console_window=true,
  )
  guard status == 0 else { abort("moon_shadow: `moon version --all` failed") }
  let output = stdout.text()
  let mut moon_version = ""
  let mut moonc_version = ""
  for line in output.split("\n") {
    // Tokens, not a field split: the trailing `~/.moon/bin/moon` is separated
    // by tabs, so `split(" ")` would glue it onto the version.
    let fields : Array[String] = []
    for token in line.replace_all(old="\t", new=" ").split(" ") {
      if !token.is_empty() {
        fields.push(token.to_owned())
      }
    }
    if fields.length() >= 2 {
      match fields[0] {
        "moon" => moon_version = fields[1]
        "moonc" => moonc_version = fields[1]
        _ => ()
      }
    }
  }
  { moon_version, moonc_version, }
}
