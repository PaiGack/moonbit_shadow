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
