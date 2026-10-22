///|
/// `<stdout>\0<exit code>`, or `None` when there is no way to spawn a process
/// on this target. The js shim crosses into `FixedArray` once: MoonBit arrays
/// and JS arrays are not the same object.
#cfg(target="js")
fn raw_run(program : String, args : Array[String]) -> (String, String)? {
  let fixed : FixedArray[String] = FixedArray::make(args.length(), "")
  for i, arg in args {
    fixed[i] = arg
  }
  spawn_js(program, fixed) |> split_spawn
}

///|
/// Native and llvm both link libc, so both spawn through `popen`. They share
/// this file because a source file can only be listed under one `targets` key.
#cfg(any(target="native", target="llvm"))
fn raw_run(program : String, args : Array[String]) -> (String, String)? {
  run_via_popen(program, args)
}

///|
#cfg(target="js")
fn split_spawn(raw : String) -> (String, String)? {
  if raw.is_empty() {
    return None
  }
  match raw.rev_find("\u{0}") {
    Some(index) => Some((raw[:index].to_owned(), raw[index + 1:].to_owned()))
    None => None
  }
}
