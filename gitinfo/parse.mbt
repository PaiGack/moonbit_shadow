///|
/// The only fields a `.git` reader cannot answer that are worth a process:
/// `commit_date`, `author` and `email` all live in the commit object, which is
/// zlib. The generator asks `git` for the three values and hands them over
/// here, so the parsing stays testable without a repository.
///
/// Split on NUL because the US separator `git log --format` uses by default can
/// appear in an author name; NUL cannot.
pub fn parse_commit_lines(raw : String) -> (String, String, String) {
  let fields = raw.split("\u{0}").map(fn(part) { trim(part) }).collect()
  match fields.length() {
    3 => (fields[0], fields[1], fields[2])
    _ => ("", "", "")
  }
}

///|
/// Whitespace off both ends, everything else kept: author names may contain
/// spaces, and an empty line is a normal answer.
///
/// Takes a `StringView` so `split` results do not have to be copied first.
fn trim(s : StringView) -> String {
  let chars = s.to_array()
  let mut end = chars.length()
  while end > 0 && is_space_char(chars[end - 1]) {
    end = end - 1
  }
  let mut start = 0
  while start < end && is_space_char(chars[start]) {
    start = start + 1
  }
  let buf = StringBuilder()
  for i in start..<end {
    buf.write_char(chars[i])
  }
  buf.to_string()
}

///|
fn is_space_char(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}
