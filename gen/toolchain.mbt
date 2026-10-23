///|
async fn collect_toolchain_versions() -> (String, String) {
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
    let fields = line.split(" ").collect()
    if fields.length() >= 2 {
      match fields[0] {
        "moon" => moon_version = fields[1].to_owned()
        "moonc" => moonc_version = fields[1].to_owned()
        _ => ()
      }
    }
  }
  guard !moon_version.is_empty() && !moonc_version.is_empty() else {
    abort(
      "moon_shadow: cannot read toolchain versions from `moon version --all`",
    )
  }
  (moon_version, moonc_version)
}
