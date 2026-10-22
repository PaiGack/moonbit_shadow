///|
/// Sole generator: `moon.mod` in, virtual package implementation out.
///
/// The last two arguments are the rule's `$input` and `$output`. `moon run`
/// may wrap the executable (`node`, `wasmtime`, `--`) and may append flags of
/// its own, so counting from this end is the only stable way to find them.
///
/// The output is always written, never diffed and skipped: if a checkout is
/// missing it because the consumer's `dev_build` rule cannot reach this package,
/// leaving it absent would break the build instead of merely going stale.
fn main {
  let args = @env.args()
  if args.length() < 2 {
    println("usage: gen <moon.mod> <output.mbt>")
    return
  }
  let input = args[args.length() - 2]
  let output = args[args.length() - 1]
  let source = @fs.read_file_to_string(input) catch {
    _ => {
      println(
        "moon_shadow: cannot read \{input}, keeping the previous \{output}",
      )
      return
    }
  }
  let parsed = @core.parse_moon_mod(name=input, source)
  for error in parsed.errors {
    println("moon_shadow: \{error}")
  }
  if parsed.info.name.is_empty() {
    println(
      "moon_shadow: \{input} has no `name`, keeping the previous \{output}",
    )
    return
  }
  @fs.write_string_to_file(output, @core.render_module_info(parsed.info)) catch {
    _ => println("moon_shadow: cannot write \{output}")
  }
}
