///|
/// `blob <len>\0<content>` through zlib, as git writes a loose object.
///
/// Every expectation below is the value `git` itself prints, captured once so
/// the reader can be checked without a repository on disk.
test "a commit object becomes its fields" {
  let object = b"commit 231\x00tree 0000000000000000000000000000000000000000\nparent 1111111111111111111111111111111111111111\nauthor Pai2s <pai2s@example.com> 1792717616 +0800\ncommitter Pai2s <pai2s@example.com> 1792717616 +0800\n\nsubject line\n"
  let commit = parse_commit(object, "2222222222222222222222222222222222222222").unwrap()
  assert_true(true)
  // `git log -1 --format=%cI`: the same instant in ISO 8601, not the raw epoch.
  assert_eq(commit.date, "2026-10-23T09:06:56+08:00")
  assert_eq(commit.author, "Pai2s")
  assert_eq(commit.email, "pai2s@example.com")
  assert_eq(commit.first_parent, "1111111111111111111111111111111111111111")
}

///|
test "a commit without a parent is a root" {
  let object = b"commit 100\x00tree 0000000000000000000000000000000000000000\nauthor A <a@b> 0 +0000\ncommitter A <a@b> 0 +0000\n\nroot\n"
  let commit = parse_commit(object, "3333333333333333333333333333333333333333").unwrap()
  assert_eq(commit.first_parent, "")
  assert_eq(commit.date, "1970-01-01T00:00:00+00:00")
}

///|
test "a header line inside the message is not a header" {
  // The body starts after the first blank line, and a message may hold any
  // line — including one that looks like `author `.
  let object = b"commit 100\x00tree 0000000000000000000000000000000000000000\nauthor Real <real@b> 1000000000 +0000\n\nmessage\nauthor Fake <fake@b> 0 +0000\n"
  let commit = parse_commit(object, "4444444444444444444444444444444444444444").unwrap()
  assert_eq(commit.author, "Real")
}

///|
test "a negative-offset timestamp reads back the same" {
  let object = b"commit 100\x00tree 0000000000000000000000000000000000000000\nauthor A <a@b> 1000000000 -0500\n\nx\n"
  let commit = parse_commit(object, "5555555555555555555555555555555555555555").unwrap()
  assert_eq(commit.date, "2001-09-08T20:46:40-05:00")
}

///|
test "an object that is not a commit answers nothing" {
  assert_true(parse_commit(b"tree 10\x00", "x") is None)
  assert_true(parse_commit(b"", "x") is None)
}

///|
test "inflate reads a zlib stream" {
  // The zlib of `blob 6\x00hello\n`, which is what git writes for
  // `printf 'hello\n' | git hash-object -w --stdin`.
  let packed = b"\x78\x9c\x4b\xca\xc9\x4f\x52\x30\x63\xc8\x48\xcd\xc9\xc9\xe7\x02\x00\x1d\xc5\x04\x14"
  let plain = @core.inflate(packed, max_size=1024).unwrap()
  assert_eq(@utf8.decode_lossy(plain), "blob 6\u{0}hello\n")
}

///|
test "inflate keeps what the length says and stops after it" {
  let packed = b"\x78\x9c\x4b\xca\xc9\x4f\x52\x30\x63\xc8\x48\xcd\xc9\xc9\xe7\x02\x00\x1d\xc5\x04\x14"
  // A cap below the real size is a stream this reader rejects, not a truncation.
  assert_eq(@core.inflate(packed, max_size=4), None)
}

///|
test "a blob id is the hash git stores" {
  // `printf 'hello\n' | git hash-object --stdin`
  assert_eq(
    @core.blob_id(b"hello\n"),
    "ce013625030ba8dba906f756967f9e9ca394464a",
  )
}

///|
test "an empty file hashes as git does" {
  // `git hash-object -w --stdin </dev/null`: the empty *blob*, not the empty
  // string's hash.
  assert_eq(@core.blob_id(b""), "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
}

///|
/// One version 2 index holding a single entry, byte for byte.
///
/// The header is network order; the entry is `stat` data + oid + flags + path,
/// padded to a multiple of 8 from the entry's own start. These bytes were built
/// by hand from RFC-less git documentation, so the test pins the layout the
/// reader assumes rather than restating its arithmetic.
test "an index entry is read back as its path and blob" {
  let raw : Array[Byte] = [
    b'\x44', b'\x49', b'\x52', b'\x43', b'\x00', b'\x00', b'\x00', b'\x02', b'\x00',
    b'\x00', b'\x00', b'\x01', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
    b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
    b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
    b'\x00', b'\x00', b'\x81', b'\xa4', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
    b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\xce', b'\x01',
    b'\x36', b'\x25', b'\x03', b'\x0b', b'\xa8', b'\xdb', b'\xa9', b'\x06', b'\xf7',
    b'\x56', b'\x96', b'\x7f', b'\x9e', b'\x9c', b'\xa3', b'\x94', b'\x46', b'\x4a',
    b'\x00', b'\x05', b'\x61', b'\x2e', b'\x74', b'\x78', b'\x74', b'\x00', b'\x00',
    b'\x00', b'\x00', b'\x00',
  ]
  let path = "/tmp/moon_shadow_index_probe"
  @fs.write_bytes_to_file(path, Bytes::from_array(raw)) catch {
    _ => return assert_true(false)
  }
  let entries = read_index(path).unwrap_or([])
  @fs.remove_file(path) catch {
    _ => ()
  }
  assert_eq(entries.length(), 1)
  assert_eq(entries[0].path, "a.txt")
  assert_eq(entries[0].blob, "ce013625030ba8dba906f756967f9e9ca394464a")
  assert_eq(entries[0].mode, 0o100644)
}
