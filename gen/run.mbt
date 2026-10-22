///|
/// Run `program args...` and return its stdout, or `None` when the program
/// could not be started or exited non-zero.
///
/// The generator is a build tool: it has to run `git`, and MoonBit's standard
/// library has no portable "spawn a process". Each backend therefore gets a
/// small shim; a target without one makes the generator report "no git", which
/// is the same answer it gives on a machine without git.
fn run(program : String, args : Array[String]) -> String? {
  match raw_run(program, args) {
    Some(("", _)) => Some("")
    Some((stdout, code)) => if code == "0" { Some(stdout) } else { None }
    None => None
  }
}
