///|
/// Sole generator: `moon.mod` plus the git checkout in, virtual package
/// implementation out.
///
/// The last two arguments are the rule's `$input` and `$output`. `moon run`
/// may wrap the executable (`node`, `wasmtime`, `--`) and may append flags of
/// its own, so counting from this end is the only stable way to find them.
/// Neither is optional: the rule is the same one shape for every consumer, and
/// nothing in it has to be rewritten by hand.
///
/// The rule's input is `moon.mod` and nothing else: git state deliberately
/// stays out of it, or every build-time write would invalidate itself — the
/// generator reports `git status`, and its own output is a tracked file. Git is
/// captured before the output is written, and `dirty` counts tracked files only,
/// so a regenerated file does not mark the build dirty. A new commit does not
/// re-trigger the rule; `moon clean` picks it up.
///
/// The output is always written, never diffed and skipped: if a checkout is
/// missing it because the consumer's `dev_build` rule cannot reach this package,
/// leaving it absent would break the build instead of merely going stale.
async fn main {
  let args = @env.args()
  if args.length() < 2 {
    println("usage: gen <moon.mod> <output.mbt>")
    return
  }
  let input = args[args.length() - 2]
  let output = args[args.length() - 1]
  // The generated file names its types by full package path, and it has to
  // agree with the consuming `pkg.mbti`. Every implementation imports them from
  // this module, so the paths are constants rather than rule arguments. See
  // `gen/render.mbt`.
  let meta_path = "PaiGack/moon_shadow/mooninfo"
  let git_path = "PaiGack/moon_shadow/gitinfo"
  let buildinfo_path = "PaiGack/moon_shadow/buildinfo"
  let source = @fs.read_file_to_string(input) catch {
    _ => {
      println(
        "moon_shadow: cannot read \{input}, keeping the previous \{output}",
      )
      return
    }
  }
  let parsed = @mooninfo.parse_moon_mod(name=input, source)
  for error in parsed.errors {
    println("moon_shadow: \{error}")
  }
  if parsed.info.name.is_empty() {
    println(
      "moon_shadow: \{input} has no `name`, keeping the previous \{output}",
    )
    return
  }
  // cwd is the consumer's module directory, so the search walks up to *their*
  // repository root — exactly whose git state we want to report.
  let cwd = dirname(input)
  let git_info = collect_git_info(cwd)
  let toolchain = collect_toolchain_info()
  let body = render(
    git_info,
    @mooninfo.render_module_info(parsed.info, pkg_path=meta_path),
    toolchain,
    git_path~,
    buildinfo_path~,
  )
  @fs.write_string_to_file(output, body) catch {
    _ => println("moon_shadow: cannot write \{output}")
  }
}

///|
/// The directory part of `path`, `.` when there is none.
///
/// Git state is discovered from the consumer's module directory, and the rule
/// hands `moon.mod` over as `../moon.mod`, so this is the only path handling
/// left in `gen`.
fn dirname(path : String) -> String {
  match path.rev_find("/") {
    Some(index) if index > 0 => path[:index].to_owned()
    Some(_) => "/"
    None => "."
  }
}
