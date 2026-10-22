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
/// wasm-gc is the module's `preferred_target`, so a plain `moon check` lands
/// here even though `shadow`'s rule always builds the generator for native: the
/// prebuild step still has to *type-check* `gen`. `run_via_popen` is gated to
/// hosts with libc, so wasm-gc gets its own gate and the honest answer — "no
/// git", the same one a machine without git gets.
#cfg(target="wasm-gc")
fn raw_run(program : String, args : Array[String]) -> (String, String)? {
  let _ = (program, args)
  None
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
