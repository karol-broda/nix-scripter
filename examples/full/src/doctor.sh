declare -A info
ctx::info -v info

ui::header "Environment"
{
  printf 'check\tvalue\n'
  for key in ci renderer os arch tty interactive color nixos wsl container nix_shell; do
    printf '%s\t%s\n' "$key" "${info[$key]:--}"
  done
} | ui::table

ui::section "Required tools"
missing=0
for tool in git jq curl; do
  if command -v "$tool" >/dev/null; then
    ui::success "$tool"
  else
    ui::error "$tool is missing"
    missing=$((missing + 1))
  fi
done
[ "$missing" -eq 0 ] || die "$missing tool(s) missing"
