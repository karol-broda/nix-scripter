inner() {
  echo "about to fail" >&2
  (exit 3)
}
outer() {
  on_exit 'echo "cleanup ran" >&2'
  inner
}

outer
echo "not reached"
