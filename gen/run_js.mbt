///|
/// Spawn `program args...` synchronously and return `[stdout, exit code]`, or
/// `undefined` when it could not be started.
///
/// `moon run --target js` executes the generator as an ES module, where
/// `require` does not exist and an `async` FFI hands back a `Promise` the
/// MoonBit side cannot wait for — both obvious routes are out. `process.binding`
/// (`spawn_sync`) is the sync primitive node's own `child_process` is built on;
/// it is internal, which is why a missing one degrades to "no git" instead of
/// throwing.
///
/// The extern returns a string that can only be `""` (could not spawn) or
/// `"<stdout>\0<exit code>"`. NUL never appears in git output, so the caller
/// splits on it without a second FFI crossing.
extern "js" fn spawn_js(program : String, args : FixedArray[String]) -> String =
  #| (program, args) => {
  #|   try {
  #|     const spawnSync = process.binding && process.binding("spawn_sync");
  #|     if (!spawnSync) return "";
  #|     // `spawn_sync` wants argv[0] to be the program name, like C's execv.
  #|     const argv = [program, ...Array.from(args)];
  #|     const envPairs = Object.keys(process.env).map((k) => k + "=" + process.env[k]);
  #|     const pipe = () => ({ type: "pipe", readable: false, writable: true });
  #|     const r = spawnSync.spawn({
  #|       file: program,
  #|       args: argv,
  #|       cwd: undefined,
  #|       envPairs,
  #|       stdio: [
  #|         { type: "pipe", readable: true, writable: false },
  #|         pipe(),
  #|         pipe(),
  #|       ],
  #|     });
  #|     const stdout = Buffer.from(r.output[1] || []).toString("utf8");
  #|     return stdout + "\u0000" + (r.status === null ? 1 : r.status);
  #|   } catch (e) {
  #|     return "";
  #|   }
  #| }
