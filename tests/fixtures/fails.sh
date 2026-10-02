inner() {
  echo "about to fail" >&2
  false
}
outer() {
  on_exit 'echo "cleanup ran" >&2'
  inner
}

outer
echo "not reached"
