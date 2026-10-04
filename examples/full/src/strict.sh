greet() {
  local name=$1
  ui::success "hello, $name"
}

for name in "$@"; do
  greet "$name"
done
