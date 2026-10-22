///|
/// Turn the text of a `moon.mod` into the implementation of the `shadow`
/// virtual package.
///
/// The mini parser lives here instead of in the library on purpose: the
/// library is what gets generated, so the generator cannot depend on it.
fn render(text : String) -> String {
  let buf = StringBuilder()
  buf.write_string("///|\n")
  buf.write_string(
    "/// Generated from `moon.mod` by the `gen` rule. Do not edit.\n",
  )
  buf.write_string("/// Run `moon check` to refresh.\n")
  for
    key in [
      "name", "version", "description", "license", "repository", "readme", "preferred_target",
    ] {
    buf.write_string("pub fn module_")
    buf.write_string(key)
    buf.write_string("() -> String {\n  ")
    buf.write_string(quote(field(text, key)))
    buf.write_string("\n}\n\n///|\n")
  }
  buf.write_string("pub fn module_keywords() -> Array[String] {\n  [")
  for i, keyword in keywords(text) {
    if i > 0 {
      buf.write_string(", ")
    }
    buf.write_string(quote(keyword))
  }
  buf.write_string("]\n}\n")
  buf.to_string()
}

///|
/// Read one top-level `key = "value"` entry, unquoted. Empty when absent.
fn field(text : String, key : String) -> String {
  for line in text.split("\n").collect() {
    let trimmed = line.to_owned().trim().to_owned()
    let index = match trimmed.find("=") {
      Some(i) => i
      None => continue
    }
    if trimmed.view(end_offset=index).to_owned().trim().to_owned() != key {
      continue
    }
    let raw = trimmed.view(start_offset=index + 1).to_owned().trim().to_owned()
    return unquote(raw)
  }
  ""
}

///|
/// Parse a `[ "a", "b" ]` value.
fn keywords(text : String) -> Array[String] {
  let list : Array[String] = []
  let raw = field(text, "keywords")
  if raw.length() < 2 || !raw.has_prefix("[") || !raw.has_suffix("]") {
    return list
  }
  let body = raw.view(start_offset=1, end_offset=raw.length() - 1).to_owned()
  for item in body.split(",").collect() {
    let item = unquote(item.to_owned().trim().to_owned())
    if item != "" {
      list.push(item)
    }
  }
  list
}

///|
fn unquote(value : String) -> String {
  let len = value.length()
  if len >= 2 {
    match (value.get_char(0), value.get_char(len - 1)) {
      (Some('"'), Some('"')) | (Some('\''), Some('\'')) =>
        return value.view(start_offset=1, end_offset=len - 1).to_owned()
      _ => ()
    }
  }
  value
}

///|
fn quote(value : String) -> String {
  let buf = StringBuilder()
  buf.write_string("\"")
  for ch in value {
    match ch {
      '"' => buf.write_string("\\\"")
      '\\' => buf.write_string("\\\\")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      _ => buf.write_char(ch)
    }
  }
  buf.write_string("\"")
  buf.to_string()
}
