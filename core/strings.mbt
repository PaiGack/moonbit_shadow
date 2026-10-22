///|
/// Resolve the escape sequences of a `moon.mod` string literal.
///
/// `moon_config` hands back the literal's raw source text (`"a \"b\""` becomes
/// `a \"b\"`), so a value that is about to be re-emitted as MoonBit source has
/// to be decoded first; otherwise every round trip doubles the backslashes.
/// Unknown escapes are kept verbatim.
pub fn unescape(raw : String) -> String {
  if !raw.contains("\\") {
    return raw
  }
  let buf = StringBuilder()
  let chars = raw.to_array()
  let mut i = 0
  while i < chars.length() {
    let ch = chars[i]
    if ch != '\\' || i + 1 >= chars.length() {
      buf.write_char(ch)
      i = i + 1
      continue
    }
    let next = chars[i + 1]
    match next {
      'n' => buf.write_char('\n')
      'r' => buf.write_char('\r')
      't' => buf.write_char('\t')
      'b' => buf.write_char('\u{8}')
      'f' => buf.write_char('\u{C}')
      'v' => buf.write_char('\u{B}')
      '0' => buf.write_char('\u{0}')
      '\\' => buf.write_char('\\')
      '"' => buf.write_char('"')
      _ => {
        // Keep the pair, so `\u{...}` and unknown escapes survive unchanged.
        buf.write_char('\\')
        buf.write_char(next)
      }
    }
    i = i + 2
  }
  buf.to_string()
}
