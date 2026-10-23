///|
/// A zlib (RFC 1950) + DEFLATE (RFC 1951) decoder, enough for a git loose
/// object.
///
/// Git compresses every loose object with zlib, so reading a commit without
/// spawning `git` means inflating it. The subset git actually produces is
/// small: one zlib stream, stored or Huffman-coded blocks, no preset
/// dictionary. Anything else yields `None` rather than a wrong answer.
fn inflate(data : Bytes, max_size~ : Int32) -> Bytes? {
  // `CMF`/`FLG`: deflate, a window of at most 32K, and a check over both bytes.
  guard data.length() >= 6 else { return None }
  guard (data[0].to_int() & 0x0F) == 8 else { return None }
  guard ((data[0].to_int() << 8) + data[1].to_int()) % 31 == 0 else {
    return None
  }
  guard (data[1].to_int() & 0x20) == 0 else { return None }
  let bits = { data, pos: 2 * 8, }
  let out : Array[Byte] = []
  let mut last_block = false
  while !last_block {
    let header = match bits.read(3) {
      Some(value) => value
      None => return None
    }
    // Bit 0 is `BFINAL`, bits 1..2 the block type.
    last_block = (header & 1) == 1
    let kind = (header >> 1) & 3
    if kind == 0 {
      // Stored: skip to a byte boundary, then a length and its complement.
      bits.align()
      let length = match bits.read(16) {
        Some(value) => value
        None => return None
      }
      let complement = match bits.read(16) {
        Some(value) => value
        None => return None
      }
      guard (length & 0xFFFF) == ((complement & 0xFFFF) ^ 0xFFFF) else {
        return None
      }
      for _ in 0..<(length & 0xFFFF) {
        let byte = match bits.byte() {
          Some(value) => value
          None => return None
        }
        out.push(byte)
      }
      continue
    }
    let tables = if kind == 1 {
      Huffman::fixed()
    } else if kind == 2 {
      match read_dynamic(bits) {
        Some(value) => value
        None => return None
      }
    } else {
      return None
    }
    // The cap is a guard against a corrupt stream, not a target: a commit
    // object is a few kilobytes, and nothing here is supposed to be huge.
    let ok = match inflate_block(bits, out, tables, max_size) {
      Some(value) => value
      None => return None
    }
    if !ok {
      return None
    }
  }
  Some(Bytes::from_array(out))
}

///|
/// A little-endian bit reader over `data`, counting bits from `pos`.
///
/// DEFLATE packs codes from the least significant bit up, which is why `read`
/// shifts left as it goes. `pos` is a mutable field of a shared struct so the
/// decoders can all read from one cursor.
priv struct Bits {
  data : Bytes
  mut pos : Int32
}

///|
fn Bits::read(self : Bits, count : Int32) -> Int32? {
  guard count >= 0 && self.pos + count <= self.data.length() * 8 else {
    return None
  }
  let mut value = 0
  for i = 0; i < count; i = i + 1 {
    let bit = self.pos + i
    let byte = self.data[bit / 8].to_int()
    if ((byte >> (bit % 8)) & 1) == 1 {
      value = value | (1 << i)
    }
  }
  self.pos = self.pos + count
  Some(value)
}

///|
fn Bits::byte(self : Bits) -> Byte? {
  match self.read(8) {
    Some(value) => Some(value.to_byte())
    None => None
  }
}

///|
fn Bits::align(self : Bits) -> Unit {
  let rest = self.pos % 8
  let _ = self.read(8 - rest)
  ()
}

///|
/// A canonical Huffman table: counts per code length, and the symbols in
/// canonical order.
priv struct Huffman {
  counts : Array[Int32]
  symbols : Array[Int32]
}

///|
/// The tables RFC 1951 pins for a fixed-Huffman block.
fn Huffman::fixed() -> (Huffman, Huffman) {
  let literals : Array[Int32] = []
  for symbol = 0; symbol < 288; symbol = symbol + 1 {
    let length = if symbol < 144 {
      8
    } else if symbol < 256 {
      9
    } else if symbol < 280 {
      7
    } else {
      8
    }
    literals.push(length)
  }
  let distances : Array[Int32] = Array::make(30, 5)
  (Huffman::make(literals), Huffman::make(distances))
}

///|
/// Canonical Huffman, as built in `puff`: count the codes of each length, then
/// hand out the symbol numbers in order.
fn Huffman::make(lengths : Array[Int32]) -> Huffman {
  let max_bits = 15
  let counts : Array[Int32] = Array::make(max_bits + 1, 0)
  for length in lengths {
    if length > 0 {
      counts[length] = counts[length] + 1
    }
  }
  let offsets : Array[Int32] = Array::make(max_bits + 1, 0)
  for i = 1; i <= max_bits; i = i + 1 {
    offsets[i] = offsets[i - 1] + counts[i - 1]
  }
  let symbols : Array[Int32] = Array::make(lengths.length(), 0)
  for symbol, length in lengths {
    if length > 0 {
      symbols[offsets[length]] = symbol
      offsets[length] = offsets[length] + 1
    }
  }
  { counts, symbols, }
}

///|
/// One symbol from the code this table describes.
///
/// Codes arrive most-significant bit first, so the accumulated value is tested
/// after every bit: the first length whose range holds it wins.
fn Huffman::decode(self : Huffman, bits : Bits) -> Int32? {
  let mut code = 0
  let mut first = 0
  let mut index = 0
  for length = 1; length <= 15; length = length + 1 {
    let bit = match bits.read(1) {
      Some(value) => value
      None => return None
    }
    code = code | bit
    if code - first < self.counts[length] {
      return Some(self.symbols[index + code - first])
    }
    index = index + self.counts[length]
    first = (first + self.counts[length]) << 1
    code = code << 1
  }
  None
}

///|
/// A code-length alphabet is written in this permuted order.
let code_length_order : Array[Int32] = [
  16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15,
]

///|
/// Length codes 257..285 -> the base length and the extra bits each stands for.
let length_table : Array[(Int32, Int32)] = [
  (3, 0),
  (4, 0),
  (5, 0),
  (6, 0),
  (7, 0),
  (8, 0),
  (9, 0),
  (10, 0),
  (11, 1),
  (13, 1),
  (15, 1),
  (17, 1),
  (19, 2),
  (23, 2),
  (27, 2),
  (31, 2),
  (35, 3),
  (43, 3),
  (51, 3),
  (59, 3),
  (67, 4),
  (83, 4),
  (99, 4),
  (115, 4),
  (131, 5),
  (163, 5),
  (195, 5),
  (227, 5),
  (258, 0),
]

///|
/// Distance codes 0..29 -> the same shape.
let distance_table : Array[(Int32, Int32)] = [
  (1, 0),
  (2, 0),
  (3, 0),
  (4, 0),
  (5, 1),
  (7, 1),
  (9, 2),
  (13, 2),
  (17, 3),
  (25, 3),
  (33, 4),
  (49, 4),
  (65, 5),
  (97, 5),
  (129, 6),
  (193, 6),
  (257, 7),
  (385, 7),
  (513, 8),
  (769, 8),
  (1025, 9),
  (1537, 9),
  (2049, 10),
  (3073, 10),
  (4097, 11),
  (6145, 11),
  (8193, 12),
  (12289, 12),
  (16385, 13),
  (24577, 13),
]

///|
/// One block's symbol stream, decoded until the end-of-block symbol. Returns
/// how much of `out` is written, or `None` on a stream this decoder rejects.
fn inflate_block(
  bits : Bits,
  out : Array[Byte],
  tables : (Huffman, Huffman),
  max_size : Int32,
) -> Bool? {
  let (literals, distances) = tables
  while true {
    let symbol = match literals.decode(bits) {
      Some(value) => value
      None => return None
    }
    if symbol < 256 {
      if out.length() >= max_size {
        return None
      }
      out.push(symbol.to_byte())
      continue
    }
    if symbol == 256 {
      // End of block.
      return Some(true)
    }
    let length_index = symbol - 257
    guard length_index >= 0 && length_index < length_table.length() else {
      return None
    }
    let (base, extra) = length_table[length_index]
    let length = match bits.read(extra) {
      Some(value) => base + value
      None => return None
    }
    let distance_symbol = match distances.decode(bits) {
      Some(value) => value
      None => return None
    }
    guard distance_symbol < distance_table.length() else { return None }
    let (distance_base, distance_extra) = distance_table[distance_symbol]
    let distance = match bits.read(distance_extra) {
      Some(value) => distance_base + value
      None => return None
    }
    guard distance <= out.length() else { return None }
    // Overlapping copies are legal and are how runs are encoded: the source
    // runs into the bytes this loop is writing.
    for _ in 0..<length {
      if out.length() >= max_size {
        return None
      }
      out.push(out[out.length() - distance])
    }
  }
  None
}

///|
/// A block header that carries its own code tables.
fn read_dynamic(bits : Bits) -> (Huffman, Huffman)? {
  let literal_count = match bits.read(5) {
    Some(value) => value
    None => return None
  }
  let distance_count = match bits.read(5) {
    Some(value) => value
    None => return None
  }
  let code_count = match bits.read(4) {
    Some(value) => value
    None => return None
  }
  guard literal_count <= 29 && distance_count <= 29 && code_count <= 15 else {
    return None
  }
  let code_lengths : Array[Int32] = Array::make(19, 0)
  for i = 0; i < code_count + 4; i = i + 1 {
    let length = match bits.read(3) {
      Some(value) => value
      None => return None
    }
    code_lengths[code_length_order[i]] = length
  }
  let code_table = Huffman::make(code_lengths)
  let lengths : Array[Int32] = []
  let total = literal_count + distance_count + 258
  while lengths.length() < total {
    let symbol = match code_table.decode(bits) {
      Some(value) => value
      None => return None
    }
    if symbol < 16 {
      lengths.push(symbol)
    } else if symbol == 16 {
      // Repeat the previous length 3..6 times.
      if lengths.length() == 0 {
        return None
      }
      let repeat = 3 +
        (match bits.read(2) {
          Some(value) => value
          None => return None
        })
      let last = lengths[lengths.length() - 1]
      for _ in 0..<repeat {
        lengths.push(last)
      }
    } else if symbol == 17 || symbol == 18 {
      // A run of zeros: 3..10 short, 11..138 long.
      let (bias, extra) = if symbol == 17 { (3, 3) } else { (11, 7) }
      let repeat = bias +
        (match bits.read(extra) {
          Some(value) => value
          None => return None
        })
      for _ in 0..<repeat {
        lengths.push(0)
      }
    } else {
      return None
    }
  }
  guard lengths.length() == total else { return None }
  let literals : Array[Int32] = []
  for i = 0; i < literal_count + 257; i = i + 1 {
    literals.push(lengths[i])
  }
  let distances : Array[Int32] = []
  for i = literal_count + 257; i < total; i = i + 1 {
    distances.push(lengths[i])
  }
  Some((Huffman::make(literals), Huffman::make(distances)))
}
