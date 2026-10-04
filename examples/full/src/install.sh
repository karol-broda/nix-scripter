os=$(ctx::os)
arch=$(ctx::arch)
url="https://example.invalid/releases/${ARG_RELEASE}/tool-${os}-${arch}.tar.gz"

ui::header "Installing tool ${ARG_RELEASE}"
ui::kv "platform" "$os/$arch"
ui::kv "prefix" "$ARG_PREFIX"

channel="" prefix=""
ui::choose -v channel --default stable "Release channel" stable beta nightly
ui::prompt -v prefix "Install prefix" "$ARG_PREFIX"

if is_true "$ARG_SYSTEM" && [ "$(id -u)" -ne 0 ]; then
  ui::warn "--system usually needs root"
fi

run curl --fail --location --output "$prefix/tool.tar.gz" "$url?channel=$channel"
ui::success "installed into $prefix"
