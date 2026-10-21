///|
/// A one-line description of the module this library was built for.
///
/// The data comes from the artifact: no `moon.mod` is read at runtime.
pub fn describe() -> String {
  let info = @modinfo.current()
  "\{info.name} \{info.version} — \{info.description}"
}
