///|
/// Resolve the escape sequences of a `moon.mod` string literal.
///
/// `moon_config` hands back the literal's raw source text (`"a \"b\""` becomes
/// `a \"b\"`), so a value that is about to be re-emitted as MoonBit source has
/// to be decoded first; otherwise every round trip doubles the backslashes.
///
/// Every sequence the MoonBit lexer recognizes is decoded, which makes `quote`
/// a true inverse and regenerating a file a no-op. Text that is not valid
/// source (a bad `\u` sequence, a trailing backslash) is kept verbatim instead
/// of being swallowed.
///
/// Quotes are not part of the value: `moon_config` hands back what is inside
/// them, and `quote` is what puts them back.
pub fn unescape(raw : String) -> String {
  let buf = StringBuilder()
  let chars = raw.to_array()
  let mut i = 0
  let end = chars.length()
  while i < end {
    let ch = chars[i]
    if ch != '\\' || i + 1 >= end {
      buf.write_char(ch)
      i = i + 1
      continue
    }
    let next = chars[i + 1]
    match next {
      'n' => {
        buf.write_char('\n')
        i = i + 2
      }
      'r' => {
        buf.write_char('\r')
        i = i + 2
      }
      't' => {
        buf.write_char('\t')
        i = i + 2
      }
      'b' => {
        buf.write_char('\u{8}')
        i = i + 2
      }
      'f' => {
        buf.write_char('\u{C}')
        i = i + 2
      }
      'v' => {
        buf.write_char('\u{B}')
        i = i + 2
      }
      '0' => {
        buf.write_char('\u{0}')
        i = i + 2
      }
      '\\' | '"' | '\'' | '`' | '/' | ' ' => {
        // The lexer accepts these and means the character itself.
        buf.write_char(next)
        i = i + 2
      }
      'u' =>
        match decode_unicode(chars, i + 2) {
          Some((decoded, width)) => {
            buf.write_char(decoded)
            i = i + 2 + width
          }
          None => {
            buf.write_char('\\')
            buf.write_char(next)
            i = i + 2
          }
        }
      'x' =>
        match digits_value(chars, i + 2, 2, 16) {
          Some(code) => {
            buf.write_char(code.unsafe_to_char())
            i = i + 4
          }
          None => {
            buf.write_char('\\')
            buf.write_char(next)
            i = i + 2
          }
        }
      'o' =>
        match digits_value(chars, i + 2, 3, 8) {
          Some(code) => {
            buf.write_char(code.unsafe_to_char())
            i = i + 5
          }
          None => {
            buf.write_char('\\')
            buf.write_char(next)
            i = i + 2
          }
        }
      // `\<newline>` swallows the newline and the following indentation: it is
      // a line continuation, the usual way to keep a long `description` tidy.
      '\n' => {
        let mut j = i + 2
        while j < end && is_blank(chars[j]) {
          j = j + 1
        }
        i = j
      }
      _ => {
        // Unknown escape: keep the pair, so nothing is silently dropped.
        buf.write_char('\\')
        buf.write_char(next)
        i = i + 2
      }
    }
  }
  buf.to_string()
}

///|
fn is_blank(ch : Char) -> Bool {
  ch == ' ' || ch == '\t'
}

///|
/// The value of `width` digits in `base` starting at `start`, or `None` when
/// they are missing or not digits in that base.
fn digits_value(
  chars : Array[Char],
  start : Int32,
  width : Int32,
  base : Int32,
) -> Int32? {
  if start + width > chars.length() {
    return None
  }
  let mut code = 0
  for offset = 0; offset < width; offset = offset + 1 {
    let digit = match chars[start + offset] {
      '0'..<='9' => chars[start + offset].to_int() - '0'.to_int()
      'a'..<='f' => chars[start + offset].to_int() - 'a'.to_int() + 10
      'A'..<='F' => chars[start + offset].to_int() - 'A'.to_int() + 10
      _ => return None
    }
    if digit >= base {
      return None
    }
    code = code * base + digit
  }
  if code > 0x10FFFF {
    return None
  }
  Some(code)
}

///|
/// `\u{1F600}` and `\u0041`; returns the decoded char and how many chars past
/// the `u` it consumed.
fn decode_unicode(chars : Array[Char], start : Int32) -> (Char, Int32)? {
  if start < chars.length() && chars[start] == '{' {
    let mut end = start + 1
    while end < chars.length() && chars[end] != '}' {
      end = end + 1
    }
    if end >= chars.length() || end == start + 1 {
      return None
    }
    match digits_value(chars, start + 1, end - start - 1, 16) {
      Some(code) => Some((code.unsafe_to_char(), end - start + 1))
      None => None
    }
  } else {
    match digits_value(chars, start, 4, 16) {
      Some(code) => Some((code.unsafe_to_char(), 4))
      None => None
    }
  }
}
