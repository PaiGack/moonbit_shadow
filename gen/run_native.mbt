///|
/// An opaque pointer: MoonBit has no pointer type, and `UInt64` — the obvious
/// stand-in — is not one either. Passing an integer where libc expects a
/// `FILE *` works or crashes depending on addressing luck, which is exactly how
/// this generator behaved before: same input, fifty-fifty build. `#external`
/// keeps the value untyped all the way across the FFI.
#cfg(any(target="native", target="llvm"))
#external
pub type Handle

///|
#cfg(any(target="native", target="llvm"))
#borrow(command, mode)
extern "C" fn c_popen(command : Bytes, mode : Bytes) -> Handle = "popen"

///|
#cfg(any(target="native", target="llvm"))
#borrow(stream)
extern "C" fn c_pclose(stream : Handle) -> Int32 = "pclose"

///|
/// NULL as it arrives from C. The comparison goes through the same opaque type
/// so no pointer is ever reinterpreted as an integer.
#cfg(any(target="native", target="llvm"))
extern "C" fn c_is_null(stream : Handle) -> Int32 = "moonbitlang_x_fs_is_null"

///|
/// `fread` rather than `fgets`: it reports how many bytes it actually read, so
/// the buffer never has to be scanned for a terminator, and binary-safe output
/// survives. `fgets` also returns a `char *` this side would have to reinterpret.
#cfg(any(target="native", target="llvm"))
#borrow(buffer, stream)
extern "C" fn c_fread(
  buffer : Bytes,
  size : Int32,
  count : Int32,
  stream : Handle,
) -> Int32 = "fread"

///|
#cfg(any(target="native", target="llvm"))
/// Spawn `program args...` through libc and return `[stdout, exit code]`, or
/// `None` when the shell could not be started.
///
/// Native is the one target that can do this honestly: `popen` waits for the
/// process to exit before `pclose` reports its status, so the whole thing stays
/// synchronous — and it needs nothing installed beyond a shell, the same one
/// `system()` would use. No `node`.
///
/// The command is built without quoting and without a `cd` prefix: `popen` hands
/// it to `/bin/sh`, every argument here is either a literal or a path the build
/// system wrote, and `git -C` does the directory part anyway.
fn run_via_popen(program : String, args : Array[String]) -> (String, String)? {
  let builder = StringBuilder()
  builder.write_string(program)
  for arg in args {
    builder.write_char(' ')
    builder.write_string(arg)
  }
  let stream = c_popen(c_string(builder.to_string()), b"r\x00")
  if c_is_null(stream) != 0 {
    return None
  }
  let buffer = Bytes::make(4096, b'\x00')
  let bytes : Array[Byte] = []
  while true {
    let read = c_fread(buffer, 1, 4096, stream)
    if read <= 0 {
      break
    }
    for i = 0; i < read; i = i + 1 {
      bytes.push(buffer[i])
    }
  }
  let status = c_pclose(stream)
  // `pclose` reports a wait status: the exit code sits in the high byte, and
  // -1 means the shell itself could not be reaped.
  let code = if status == -1 { -1 } else { (status >> 8) & 0xFF }
  Some((@utf8.decode_lossy(Bytes::from_array(bytes)), code.to_string()))
}

///|
#cfg(any(target="native", target="llvm"))
/// `text` as the NUL-terminated `const char *` that `popen` reads up to.
///
/// `String::to_bytes` is packed — one NUL between chars, so `popen` would see an
/// empty command. `@utf8.encode` is the only producer of plain bytes, so it is
/// the one that gets the terminator appended.
fn c_string(text : String) -> Bytes {
  @utf8.encode(text) + b"\x00"
}
