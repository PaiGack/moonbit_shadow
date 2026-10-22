///|
/// No way to spawn a process here. `moon` runs the generator on native, llvm,
/// js or wasm-gc; wasm and wasm-gc have no process model at all, so the
/// generator reports "no git here" — the same answer it gives on a machine
/// without git — instead of failing a consumer's build for something they
/// cannot fix.
#cfg(any(target="wasm", target="wasm-gc"))
fn raw_run(program : String, args : Array[String]) -> (String, String)? {
  let _ = (program, args)
  None
}
