///|
/// Sole generator: `moon.mod` plus the git checkout in, virtual package
/// implementation out.
///
/// The last two arguments are the rule's `$input` and `$output`. `moon run`
/// may wrap the executable (`node`, `wasmtime`, `--`) and may append flags of
/// its own, so counting from this end is the only stable way to find them.
///
/// The rule's input is `moon.mod` and nothing else: git state deliberately
/// stays out of it, or every build-time write would invalidate itself — the
/// generator commits `git status`, and its own output is a tracked file. Git is
/// captured before the output is written, and `dirty` counts tracked files only
/// (`--untracked-files=no`), so a regenerated file does not mark the build
/// dirty. A new commit does not re-trigger the rule; `moon clean` picks it up.
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
  // cwd is the consumer's module directory, so `rev-parse` walks up to *their*
  // repository root — exactly whose git state we want to report.
  let cwd = @path.dirname(input)
  let git_info = if git_available(cwd) {
    RawGitInfo::collect(cwd).to_git_info()
  } else {
    println(
      "moon_shadow: \{cwd} is not a git work tree, baking in git_info().available = false",
    )
    @gitinfo.GitInfo::none()
  }
  let body = render(git_info, @core.render_module_info(parsed.info))
  @fs.write_string_to_file(output, body) catch {
    _ => println("moon_shadow: cannot write \{output}")
  }
}
