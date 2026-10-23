///|
/// Whether tracked files differ from what `HEAD` recorded.
///
/// `git status --porcelain --untracked-files=no` without the process. The index
/// already carries the blob id git found when the file was last staged, so a
/// tracked file is clean exactly when its content still hashes to that id —
/// `git diff-files` asked by hand, and the only comparison that cannot be
/// fooled by a copied timestamps. Untracked files are ignored on purpose:
/// `generated.mbt` is committed, and writing it must not mark every build
/// dirty.
///
/// The cost is hashing every tracked file. A module is a few hundred files and
/// the generator runs once per `moon.mod` change, so that is cheaper than the
/// `stat`-based shortcut plus the `mtime` races it introduces.
fn Repo::is_dirty(self : Repo) -> Bool {
  let index = match read_index(join_path(self.git_dir, "index")) {
    Some(entries) => entries
    None => return false
  }
  for entry in index {
    // A symlink hashes its target path, and `@fs` follows links rather than
    // reading them, so this entry cannot be checked here. Skipping it keeps a
    // clean checkout clean; the cost is that editing a link's own target is
    // missed, which is the one case a `git status` on the same files would
    // also have to re-read.
    if entry.mode == 0o120000 {
      continue
    }
    let path = join_path(self.work_dir, entry.path)
    // A deleted file is a change; so is one whose content no longer matches.
    let content = @fs.read_file_to_bytes(path) catch { _ => return true }
    if blob_id(content) != entry.blob {
      return true
    }
  }
  false
}

///|
/// One entry of `.git/index`: the path, the blob it was staged as, and the
/// mode that tells a symlink from a regular file.
priv struct IndexEntry {
  path : String
  /// 40 hex characters, lower case.
  blob : String
  /// `0o120000` for a symlink, `0o100644` / `0o100755` for a file.
  mode : Int32
}

///|
/// `.git/index`, version 2 or 3.
///
/// Version 4 delta-compresses paths and is left out: it only appears when
/// someone sets `index.version=4`, and "not checked" beats half-reading it.
fn read_index(path : String) -> Array[IndexEntry]? {
  let bytes = @fs.read_file_to_bytes(path) catch { _ => return None }
  guard bytes.length() >= 12 else { return None }
  guard bytes[0] == b'D' &&
    bytes[1] == b'I' &&
    bytes[2] == b'R' &&
    bytes[3] == b'C' else {
    return None
  }
  let version = read_u32(bytes, 4)
  guard version == 2 || version == 3 else { return None }
  let count = read_u32(bytes, 8)
  let entries : Array[IndexEntry] = []
  let mut pos = 12
  for _ in 0..<count {
    // Ten 4-byte numbers, then a 20-byte object id and the flags.
    guard pos + 62 <= bytes.length() else { return None }
    let flags = read_u16(bytes, pos + 60)
    // Bit 14 is the "extended" flag. It only appears in a version 3 index,
    // where two extra bytes sit between the flags and the path — so the path
    // length is read first and the skip happens after.
    let mut name_at = pos + 62
    if (flags & 0x4000) != 0 {
      name_at = name_at + 2
    }
    let mut name_length = flags & 0xFFF
    if name_length == 0xFFF {
      // Long path: the length field saturates, so the name ends at its NUL.
      let mut end = name_at
      while end < bytes.length() && bytes[end] != b'\x00' {
        end = end + 1
      }
      name_length = end - name_at
    }

    guard name_at + name_length <= bytes.length() else { return None }
    let name_bytes : Array[Byte] = []
    for i in 0..<name_length {
      name_bytes.push(bytes[name_at + i])
    }
    entries.push({
      path: @utf8.decode_lossy(Bytes::from_array(name_bytes)),
      blob: hex_of(bytes, slide=pos + 40, length=20),
      mode: read_u32(bytes, pos + 24),
    })
    // An entry is its fixed part, the path, at least one NUL, then padding to a
    // multiple of 8 measured from the entry's start — so `+ 8` before masking,
    // which is what guarantees that trailing NUL.
    let unaligned = name_at - pos + name_length + 8
    let padded = unaligned - unaligned % 8
    pos = pos + padded
  }
  Some(entries)
}

///|
/// `length` bytes at `slide` as lower-case hex.
fn hex_of(bytes : Bytes, slide~ : Int32, length~ : Int32) -> String {
  let out = StringBuilder()
  for i in 0..<length {
    let byte = bytes[slide + i].to_int()
    out.write_char(hex_digit((byte >> 4) & 0xF))
    out.write_char(hex_digit(byte & 0xF))
  }
  out.to_string()
}

///|
fn hex_digit(value : Int32) -> Char {
  let code = if value < 10 {
    '0'.to_int() + value
  } else {
    'a'.to_int() + value - 10
  }
  code.unsafe_to_char()
}

///|
/// `bytes[at..at+4]`, big-endian: `.git/index` is network byte order, unlike
/// the commit object's dates.
///
/// Folded as `high * 65536 + low` rather than shifted: under wasm-gc `Int` is
/// 64-bit, and a shift amount that is itself an `Int` is sized by that width,
/// which is one way to land the bytes on the wrong end.
fn read_u32(bytes : Bytes, at : Int32) -> Int32 {
  let high = read_u16(bytes, at)
  let low = read_u16(bytes, at + 2)
  let hi = high * 65536
  hi + low
}

///|
fn read_u16(bytes : Bytes, at : Int32) -> Int32 {
  let first : Int32 = bytes[at].to_int()
  let second : Int32 = bytes[at + 1].to_int()
  let scaled = first * 256
  scaled + second
}

///|
/// How far `HEAD` is ahead of, and behind, the branch it tracks.
///
/// `rev-list --left-right --count HEAD...@{upstream}` without the process: walk
/// both histories by first parent, mark what `HEAD` reaches, then count what
/// the upstream reaches that `HEAD` does not (behind) and the other way round
/// (ahead). `(0, 0)` when the branch tracks nothing — a branch nobody tracks is
/// neither ahead nor behind, which is what git reports too.
fn Repo::tracking(
  self : Repo,
  branch : String,
  head : Commit,
) -> (Int32, Int32) {
  guard !branch.is_empty() else { return (0, 0) }
  let upstream = match self.upstream_of(branch) {
    Some(name) => self.read_ref(name, 0)
    None => return (0, 0)
  }
  guard !upstream.is_empty() else { return (0, 0) }
  let theirs = match self.read_commit(upstream) {
    Some(commit) => commit
    None => return (0, 0)
  }
  let mine = self.walk(head.first_parent)
  let ours = self.walk(theirs.first_parent)
  let mut ahead = 0
  for id, _ in mine {
    if !ours.contains(id) {
      ahead = ahead + 1
    }
  }
  let mut behind = 0
  for id, _ in ours {
    if !mine.contains(id) {
      behind = behind + 1
    }
  }
  (ahead, behind)
}

///|
/// Every commit id reachable from `start` by first parent.
///
/// First parent only: `ahead` / `behind` are asked of a branch, and a branch
/// with merges is still one line of commits as far as its own history goes.
/// Stops at the repository root, at an unreadable object, and at `max_depth`, so
/// a corrupt or enormous history cannot make a build hang.
fn Repo::walk(self : Repo, start : String) -> Map[String, Unit] {
  let seen : Map[String, Unit] = Map([])
  let mut next = start
  let mut depth = 0
  while !next.is_empty() && depth < 10000 {
    if seen.contains(next) {
      break
    }
    seen[next] = ()
    let commit = match self.read_commit(next) {
      Some(commit) => commit
      None => break
    }
    next = commit.first_parent
    depth = depth + 1
  }
  seen
}

///|
/// The branch `branch` tracks, from `.git/config`.
///
/// `.git/config` is an INI file, and the one key that matters is
/// `branch.<name>.merge` under the section `[branch "<name>"]`; `remote` says
/// which remote's refs to look under, defaulting to the one named in
/// `branch.<name>.remote` (usually `origin`).
fn Repo::upstream_of(self : Repo, branch : String) -> String? {
  let config = read_text(join_path(self.common_dir, "config"))
  let section = "branch \"" + branch + "\""
  let mut in_section = false
  let mut remote = ""
  let mut merge = ""
  for line in config.split("\n") {
    let entry = trim(line)
    if entry.is_empty() || entry.has_prefix("#") || entry.has_prefix(";") {
      continue
    }
    if entry.has_prefix("[") {
      in_section = entry[1:entry.length() - 1]
        .to_owned()
        .replace_all(old="\"", new="\"") ==
        section
      continue
    }
    guard in_section else { continue }
    let (key, value) = match entry.find("=") {
      Some(index) =>
        (trim(entry[:index]).to_lower(), trim(entry[index + 1:].to_owned()))
      None => continue
    }
    if key == "merge" {
      merge = value
    } else if key == "remote" {
      remote = value
    }
  }
  guard !merge.is_empty() else { return None }
  // `refs/heads/main` on `origin` -> `refs/remotes/origin/main`.
  let head = "refs/heads/"
  let name = if merge.has_prefix(head) {
    merge[head.length():].to_owned()
  } else {
    merge
  }
  if remote.is_empty() || remote == "." {
    Some("refs/heads/" + name)
  } else {
    Some("refs/remotes/" + remote + "/" + name)
  }
}
