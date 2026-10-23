///|
/// `path` as one joined path.
///
/// Kept dumb on purpose: both sides come from git metadata (`commondir: ../..`
/// above all), and there is no path library on every toolchain this package is
/// type-checked for. Trailing separators are dropped, `..` is resolved halfway
/// in `normalize` where the whole path is known.
fn join_path(left : String, right : String) -> String {
  if right.has_prefix("/") {
    return normalize(right)
  }
  if left.is_empty() || left == "." {
    return normalize(right)
  }
  let base = if left.has_suffix("/") {
    left[:left.length() - 1].to_owned()
  } else {
    left
  }
  normalize(base + "/" + right)
}

///|
/// `path` with separators made `/` and `.` / `..` resolved textually.
///
/// Textually rather than by `getcwd` on purpose: `commondir` can name a
/// directory git would refuse to enter, and following it with the filesystem is
/// how a build tool ends up walking somewhere it should not have.
fn normalize(path : String) -> String {
  let absolute = path.has_prefix("/")
  let parts : Array[String] = []
  for part in path.replace_all(old="\\", new="/").split("/") {
    if part.is_empty() || part == "." {
      continue
    }
    if part == ".." {
      if parts.length() > 0 && parts[parts.length() - 1] != ".." {
        let _ = parts.pop()
      } else if !absolute {
        parts.push(part.to_owned())
      }
      continue
    }
    parts.push(part.to_owned())
  }
  let joined = parts.join("/")
  if absolute {
    "/" + joined
  } else if joined.is_empty() {
    "."
  } else {
    joined
  }
}

///|
/// The directory part of `path`, `.` when there is none.
///
/// Hand-rolled for the same reason as the rest of this file: the only caller
/// wants the directory of `moon.mod`, and the rule reads `../moon.mod`.
fn dirname(path : String) -> String {
  match path.rev_find("/") {
    Some(index) if index > 0 => path[:index].to_owned()
    Some(_) => "/"
    None => "."
  }
}

///|
/// `path` names a directory. Missing and unreadable are the same answer: there
/// is nothing to descend into either way.
fn is_dir(path : String) -> Bool {
  @fs.is_dir(path) catch {
    _ => false
  }
}

///|
/// `path` names a regular file.
fn is_file(path : String) -> Bool {
  @fs.is_file(path) catch {
    _ => false
  }
}

///|
/// The contents of `path` with line noise stripped, or `""` when it is not
/// there.
///
/// `@fs` rather than an `fopen` of our own because this package is also
/// type-checked for wasm-gc, where a native-only FFI would not resolve.
fn read_text(path : String) -> String {
  let bytes = @fs.read_file_to_bytes(path) catch { _ => return "" }
  strip_git_whitespace(@utf8.decode_lossy(bytes))
}

///|
/// Whitespace off both ends, everything else kept.
///
/// Not `String::trim`: a ref name may hold any byte the filesystem allows, and
/// only the line ending git wrote is noise there.
fn strip_git_whitespace(text : StringView) -> String {
  let chars = text.to_array()
  let mut end = chars.length()
  while end > 0 && is_whitespace(chars[end - 1]) {
    end = end - 1
  }
  let mut start = 0
  while start < end && is_whitespace(chars[start]) {
    start = start + 1
  }
  let buf = StringBuilder()
  for i in start..<end {
    buf.write_char(chars[i])
  }
  buf.to_string()
}

///|
fn is_whitespace(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}
