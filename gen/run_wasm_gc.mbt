///|
/// `moon run` on wasm-gc cannot spawn a process, so the generator reports "no
/// git here" — the same answer it gives on a machine without git — instead of
/// failing a consumer's build for a reason they cannot fix.
#cfg(target="wasm-gc")
fn raw_run(program : String, args : Array[String]) -> (String, String)? {
  let _ = (program, args)
  None
}
