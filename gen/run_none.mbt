///|
/// No way to spawn a process here. wasm has no process model at all, so the
/// generator reports "no git here" — the same answer it gives on a machine
/// without git — instead of failing a consumer's build for something they
/// cannot fix.
///
/// wasm-gc used to be listed here too, which broke native: `options(targets:)`
/// picks which files a target compiles, and listing a *file* under wasm-gc made
/// MoonBit look up `raw_run` for the module's `preferred_target` build as well.
/// It found one in `moonbitlang/x` — a different function with the same name —
/// so the native build had no shim of its own and the regex in a dependency
/// took the blame. One hook per target, and wasm-gc gets its own in
/// `run_targets.mbt`.
#cfg(target="wasm")
fn raw_run(program : String, args : Array[String]) -> (String, String)? {
  let _ = (program, args)
  None
}
