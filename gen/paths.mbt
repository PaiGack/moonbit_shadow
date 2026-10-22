///|
/// First value of a `--flag value` pair in `args`, or `""`.
///
/// Deliberately tiny: the generator has one option, and pulling in an argument
/// parser would add a dependency to the package every consumer of this library
/// has to compile.
fn flag(args : Array[String], name : String) -> String {
  for i = 0; i + 1 < args.length(); i = i + 1 {
    if args[i] == name {
      return args[i + 1]
    }
  }
  ""
}

///|
/// Directory part of `path`, `"."` when there is none.
///
/// Hand-rolled because `moonbitlang/core/path` is not available on every
/// toolchain, and the only caller wants the directory of a sibling file.
fn dirname(path : String) -> String {
  match path.rev_find("/") {
    Some(index) if index > 0 => path[:index].to_owned()
    Some(_) => "/"
    None => "."
  }
}
