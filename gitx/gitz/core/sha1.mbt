///|
/// SHA-1 over `content`, as git spells it for a blob.
///
/// Git hashes `blob <size>\0<content>`, and the hex of that is the object id the
/// index stores — which is what makes "has this file changed" answerable by
/// reading it, without trusting a timestamp. SHA-1 is here rather than in a
/// dependency because it is forty lines and every target can run it.
pub fn blob_id(content : Bytes) -> String {
  let header = "blob " + content.length().to_string() + "\u{0}"
  let header_bytes = @utf8.encode(header)
  sha1_hex(header_bytes + content)
}

///|
pub fn sha1_hex(data : Bytes) -> String {
  let state : Array[Int32] = [
    0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0,
  ]
  // Pad to 64-byte blocks: 0x80, then zeros, then the bit length as a 64-bit
  // big-endian number.
  let length = data.length()
  let blocks : Array[Byte] = []
  for i in 0..<length {
    blocks.push(data[i])
  }
  blocks.push(b'\x80')
  while blocks.length() % 64 != 56 {
    blocks.push(b'\x00')
  }
  let bits = length.to_int64() * 8L
  for i = 7; i >= 0; i = i - 1 {
    blocks.push(((bits >> (8 * i)) & 0xFFL).to_byte())
  }
  let mut offset = 0
  while offset < blocks.length() {
    let words : Array[Int32] = []
    for i in 0..<16 {
      let at = offset + 4 * i
      words.push(
        (blocks[at].to_int() << 24) |
        (blocks[at + 1].to_int() << 16) |
        (blocks[at + 2].to_int() << 8) |
        blocks[at + 3].to_int(),
      )
    }
    for i in 16..<80 {
      let value = words[i - 3] ^ words[i - 8] ^ words[i - 14] ^ words[i - 16]
      words.push(((value << 1) | ((value >> 31) & 1)) & 0xFFFFFFFF)
    }
    let mut a = state[0]
    let mut b = state[1]
    let mut c = state[2]
    let mut d = state[3]
    let mut e = state[4]
    for i in 0..<80 {
      let (f, k) = if i < 20 {
        ((b & c) | ((b ^ 0xFFFFFFFF) & d), 0x5A827999)
      } else if i < 40 {
        (b ^ c ^ d, 0x6ED9EBA1)
      } else if i < 60 {
        ((b & c) | (b & d) | (c & d), 0x8F1BBCDC)
      } else {
        (b ^ c ^ d, 0xCA62C1D6)
      }
      let temp = (((a << 5) | ((a >> 27) & 0x1F)) + f + e + k + words[i]) &
        0xFFFFFFFF
      e = d
      d = c
      c = ((b << 30) | ((b >> 2) & 0x3FFFFFFF)) & 0xFFFFFFFF
      b = a
      a = temp
    }
    state[0] = (state[0] + a) & 0xFFFFFFFF
    state[1] = (state[1] + b) & 0xFFFFFFFF
    state[2] = (state[2] + c) & 0xFFFFFFFF
    state[3] = (state[3] + d) & 0xFFFFFFFF
    state[4] = (state[4] + e) & 0xFFFFFFFF
    offset = offset + 64
  }
  let out = StringBuilder()
  for word in state {
    for i = 3; i >= 0; i = i - 1 {
      let byte = (word >> (8 * i)) & 0xFF
      out.write_char(hex_digit((byte >> 4) & 0xF))
      out.write_char(hex_digit(byte & 0xF))
    }
  }
  out.to_string()
}

///|
/// `0`..`15` -> `'0'`..`'f'`, the form git prints object ids in.
pub fn hex_digit(value : Int32) -> Char {
  let code = if value < 10 {
    '0'.to_int() + value
  } else {
    'a'.to_int() + value - 10
  }
  code.unsafe_to_char()
}
