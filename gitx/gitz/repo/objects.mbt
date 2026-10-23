///|
/// A commit object, inflated and parsed far enough to answer the fields
/// `GitInfo` keeps.
///
/// Objects are zlib streams, so reading one means inflating it. Doing it here
/// rather than shelling out to `git log -1` is what keeps the generator free of
/// a process: same files, same answers, no shell to find.
pub(all) struct Commit {
  /// `2026-10-22T09:14:41+08:00`, as written in the object.
  date : String
  /// The author's name, not the committer's: `git log -1 --format=%an`.
  author : String
  email : String
  /// The first `parent` line, for `ahead` / `behind`.
  first_parent : String
}

///|
/// `commit` as a `Commit`, or `None` when the object is not there or is not
/// zlib this reader can inflate.
///
/// A loose object is `<common>/objects/<2 hex>/<38 hex>`. A packed one is not
/// read: packs are the one place where "read the files yourself" stops being
/// worth the code, so a freshly `git gc`ed clone degrades to an empty commit
/// date instead of a wrong one.
pub fn Repo::read_commit(self : Repo, id : String) -> Commit? {
  guard id.length() >= 40 && is_hex(id[:40]) else { return None }
  let hex = id[:40].to_owned()
  let path = join_path(
    self.common_dir,
    "objects/" + hex[:2].to_owned() + "/" + hex[2:].to_owned(),
  )
  let raw = @fs.read_file_to_bytes(path) catch { _ => return None }
  let object = match @core.inflate(raw, max_size=1 << 20) {
    Some(object) => object
    None => return None
  }
  parse_commit(object, id)
}

///|
/// `commit <size>\0<body>` -> the body's fields.
fn parse_commit(object : Bytes, id : String) -> Commit? {
  let text = @utf8.decode_lossy(object)
  // The header is ASCII and the body may not be, so the split is on the first
  // NUL only, never on a decoded boundary.
  guard text.has_prefix("commit ") else { return None }
  let body = match text.find("\u{0}") {
    Some(index) => text[index + 1:]
    None => return None
  }
  let mut date = ""
  let mut author = ""
  let mut email = ""
  let mut parent = ""
  let mut in_header = true
  for line in body.split("\n") {
    // The header ends at the first blank line; a commit message may hold
    // anything, including lines that look like headers.
    if line.is_empty() {
      in_header = false
      continue
    }
    guard in_header else { continue }
    if line.has_prefix("parent ") && parent.is_empty() {
      // The first parent is the mainline; a merge's other parents say nothing
      // about how far ahead of a branch this commit is.
      parent = line[7:].to_owned()
    } else if line.has_prefix("author ") {
      let fields = parse_identity(line[7:].to_owned())
      date = fields.0
      author = fields.1
      email = fields.2
    }
  }
  let _ = id
  Some({ date, author, email, first_parent: parent, })
}

///|
/// `Name <email> 1761124481 +0800` -> `(ISO date, name, email)`.
///
/// The timestamp is unix seconds plus a `+HHMM` offset, and `%cI` is that in
/// ISO 8601 — the same instant, in the form a caller can sort as text.
fn parse_identity(text : String) -> (String, String, String) {
  let open = text.rev_find("<")
  let close = text.rev_find(">")
  guard open is Some(open) && close is Some(close) && open < close else {
    return ("", "", "")
  }
  let name = trim(text[:open].to_owned())
  let email = text[open + 1:close].to_owned()
  // `> 1761124481 +0800`: the offset is the last field, the timestamp the one
  // before it. `rev_split` rather than `split` because the space before the
  // timestamp is the only separator that matters.
  let rest = text[close + 1:].to_owned()
  let fields = rest.split(" ").collect()
  let (seconds, offset) = match fields.rev() {
    [offset, seconds, ..] => (seconds.to_owned(), offset.to_owned())
    _ => return ("", name, email)
  }
  (iso_date(seconds, offset), name, email)
}

///|
/// Unix seconds plus a `+HHMM` offset -> `YYYY-MM-DDTHH:MM:SS+HH:MM`.
fn iso_date(seconds : String, offset : String) -> String {
  let timestamp = match parse_u64(seconds) {
    Some(value) => value
    None => return ""
  }
  let zone = parse_zone(offset)
  // A timestamp is UTC; the offset git records is the author's, so the printed
  // clock time is shifted by it and then labelled with it.
  let shifted = timestamp + zone.0
  let days = shifted / 86400
  let rest = shifted % 86400
  let (year, month, day) = civil_from_days(days)
  let text = StringBuilder()
  text.write_string(pad(year, 4))
  text.write_char('-')
  text.write_string(pad(month, 2))
  text.write_char('-')
  text.write_string(pad(day, 2))
  text.write_char('T')
  text.write_string(pad(rest / 3600, 2))
  text.write_char(':')
  text.write_string(pad(rest % 3600 / 60, 2))
  text.write_char(':')
  text.write_string(pad(rest % 60, 2))
  text.write_string(zone.1)
  text.to_string()
}

///|
/// `+0800` -> `(28800, "+08:00")`. A missing or unparsable offset reads as UTC,
/// which is wrong by at most half a day and never by a century.
fn parse_zone(offset : String) -> (Int64, String) {
  guard offset.length() == 5 else { return (0L, "+00:00") }
  let sign = match offset[:1] {
    "-" => -1L
    "+" => 1L
    _ => return (0L, "+00:00")
  }
  let hours = parse_u64(offset[1:3]).unwrap_or(0L)
  let minutes = parse_u64(offset[3:5]).unwrap_or(0L)
  let delta = sign * (hours * 3600L + minutes * 60L)
  let label = "\{offset[:3]}:\{offset[3:5]}"
  (delta, label)
}

///|
fn parse_u64(text : StringView) -> Int64? {
  guard text.length() > 0 else { return None }
  let mut value = 0L
  for ch in text {
    guard ch >= '0' && ch <= '9' else { return None }
    value = value * 10L + (ch.to_int().to_int64() - '0'.to_int().to_int64())
  }
  Some(value)
}

///|
fn pad(value : Int64, width : Int32) -> String {
  let text = value.to_string()
  let out = StringBuilder()
  for _ in 0..<(width - text.length()) {
    out.write_char('0')
  }
  out.write_string(text)
  out.to_string()
}

///|
/// Days since 1970-01-01 -> `(year, month, day)`.
///
/// Howard Hinnant's `civil_from_days`: the era-based form has no loops, so no
/// case where a leap year is off by one.
fn civil_from_days(days : Int64) -> (Int64, Int64, Int64) {
  let z = days + 719468L
  let era = if z >= 0 { z / 146097L } else { (z - 146096L) / 146097L }
  let doe = z - era * 146097L
  let yoe = (doe - doe / 1460L + doe / 36524L - doe / 146096L) / 365L
  let y = yoe + era * 400L
  let doy = doe - (365L * yoe + yoe / 4L - yoe / 100L)
  let mp = (5L * doy + 2L) / 153L
  let d = doy - (153L * mp + 2L) / 5L + 1L
  let m = if mp < 10L { mp + 3L } else { mp - 9L }
  (if m <= 2L { y + 1L } else { y }, m, d)
}
