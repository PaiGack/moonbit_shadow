///|
/// `popen`'s return value travels as an integer: MoonBit has no opaque pointer
/// type to hand back across the FFI, and `UInt64` is how it fits on every 64-bit
/// host.
#cfg(any(target="native", target="llvm"))
pub type Handle = UInt64

///|
#cfg(any(target="native", target="llvm"))
#borrow(command, mode)
extern "C" fn c_popen(command : Bytes, mode : Bytes) -> Handle = "popen"

///|
#cfg(any(target="native", target="llvm"))
#borrow(stream)
extern "C" fn c_pclose(stream : Handle) -> Int32 = "pclose"

///|
#cfg(any(target="native", target="llvm"))
#borrow(buffer, stream)
extern "C" fn c_fgets(buffer : Bytes, size : Int32, stream : Handle) -> Handle = "fgets"

///|
#cfg(any(target="native", target="llvm"))
#borrow(destination, source)
extern "C" fn c_memcpy(
  destination : Bytes,
  source : Bytes,
  count : Int32,
) -> Bytes = "memcpy"

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
  // `2>/dev/null`: git prints "fatal: No names found" for an untagged repo and
  // a complaint for a missing upstream, both of which are ordinary answers
  // here — the field simply stays empty. Left alone, the shell would copy them
  // straight into the build log on every build.
  let stream = c_popen(c_string(builder.to_string() + " 2>/dev/null"), b"r\x00")
  if stream.reinterpret_as_int64() == 0 {
    return None
  }
  let buffer = Bytes::make(4096, b'\x00')
  let bytes : Array[Byte] = []
  while c_fgets(buffer, 4096, stream).reinterpret_as_int64() != 0 {
    for i = 0; i < 4096; i = i + 1 {
      if buffer[i] == b'\x00' {
        break
      }
      bytes.push(buffer[i])
    }
  }
  let status = c_pclose(stream)
  // `pclose` reports a wait status: the exit code sits in the high byte, and
  // -1 means the shell itself could not be reaped.
  let code = if status == -1 { -1 } else { (status >> 8) & 0xFF }
  Some((bytes_to_string(bytes), code.to_string()))
}

///|
#cfg(any(target="native", target="llvm"))
/// `text` as the NUL-terminated `const char *` that `popen` reads up to.
///
/// `String::to_bytes` is packed — one NUL between chars, so `popen` would see an
/// empty command. `@utf8.encode` is the only producer of plain bytes, but it drops
/// the NUL terminator; copying it into a buffer whose last byte is already NUL
/// keeps both.
fn c_string(text : String) -> Bytes {
  let encoded : Bytes = @utf8.encode(text)
  let command = Bytes::make(encoded.length() + 1, b'\x00')
  let _ = c_memcpy(command, encoded, encoded.length())
  command
}

///|
#cfg(any(target="native", target="llvm"))
fn bytes_to_string(bytes : Array[Byte]) -> String {
  let builder = StringBuilder()
  for byte in bytes {
    builder.write_char(byte.to_char())
  }
  builder.to_string()
}
