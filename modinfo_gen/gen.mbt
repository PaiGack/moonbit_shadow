///|
/// `moon run` appends the arguments after `--`, so the last two of them are
/// the input `moon.mod` and the output file.
fn main {
  let args = @env.args()
  let input = if args.length() >= 2 {
    args[args.length() - 2]
  } else {
    "moon.mod"
  }
  let output = if args.length() >= 3 {
    args[args.length() - 1]
  } else {
    "modinfo/module_info.mbt"
  }
  let source = @fs.read_file_to_string(input) catch {
    _ => {
      println(
        "moon_shadow: cannot read \{input}, keeping the previous generated file",
      )
      return
    }
  }
  let parsed = @modfile.parse_moon_mod(name=input, source)
  for error in parsed.errors {
    println("moon_shadow: \{error}")
  }
  if parsed.info.name.is_empty() {
    println(
      "moon_shadow: \{input} has no `name`, keeping the previous generated file",
    )
    return
  }
  let written = try {
    @fs.write_string_to_file(
      output,
      @modinfo_gen_codegen.render_module_info(parsed.info),
    )
    true
  } catch {
    _ => false
  }
  if !written {
    println(
      "moon_shadow: cannot write \{output}, keeping the previous generated file",
    )
  }
}
