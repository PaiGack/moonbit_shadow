///|
/// Regenerate `generated.mbt` in the module root from `moon.mod`.
///
/// Invoked by the `gen` rule; not meant to be run by users. This package must
/// not import anything from the module: building it would otherwise re-enter
/// `dev_build` and recurse forever.
fn main {
  let args = @env.args()
  if args.length() < 2 {
    println("usage: gen <moon.mod> <output.mbt>")
    return
  }
  // The JS backend puts `node` and the script path first, so take from the end.
  let input = args[args.length() - 2]
  let output = args[args.length() - 1]
  let text = @fs.read_file_to_string(input) catch {
    _ => {
      println("moon_shadow: cannot read \{input}")
      return
    }
  }
  let rendered = render(text)
  let previous = @fs.read_file_to_string(output) catch { _ => "" }
  if previous == rendered {
    return
  }
  @fs.write_string_to_file(output, rendered) catch {
    _ => println("moon_shadow: cannot write \{output}")
  }
}
