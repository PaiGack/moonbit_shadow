///|
test "generated metadata is never empty" {
  assert_true(@shadow.module_name() != "")
}
