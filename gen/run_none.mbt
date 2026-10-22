///|
/// No way to spawn a process on this target — `moon` only ever runs the
/// generator on node (js) or wasm-gc, so these are belt and braces. The
/// generator then reports "no git here", the same answer it gives on a machine
/// without git, instead of failing a consumer's build for something they cannot
/// fix.
#cfg(target="wasm")
fn raw_run(program : String, args : Array[String]) -> (String, String)? {
  let _ = (program, args)
  None
}

///|
#cfg(target="native")
fn raw_run(program : String, args : Array[String]) -> (String, String)? {
  let _ = (program, args)
  None
}

///|
#cfg(target="llvm")
fn raw_run(program : String, args : Array[String]) -> (String, String)? {
  let _ = (program, args)
  None
}
