{
  pkgs,
  lib,
  scripter,
  runTest,
  ...
}:
let
  standaloneScript = scripter.bash {
    name = "portable";
    imports = [ scripter.presets.portable ];
    features.ui = true;
    deps = [ pkgs.jq ];
    requires = [ "definitely-not-a-command-xyz" ];
    args.options.name.default = "world";
    text = ''
      ui::info "hello ''${ARG_NAME}"
    '';
  };

in
{
  standalone = runTest "standalone" [ pkgs.jq ] ''
    f=${standaloneScript}/bin/portable
    ! grep -q /nix/store "$f" || fail "store path in standalone script"
    IFS= read -r shebang < "$f"
    [ "$shebang" = '#!/usr/bin/env bash' ] || fail "wrong shebang: $shebang"
    rc=0
    bash "$f" 2> missing.txt || rc=$?
    [ "$rc" -eq 127 ] || fail "expected exit 127, got $rc"
    expect_contains missing.txt "missing required commands: definitely-not-a-command-xyz"
    mkdir bin && printf '#!/bin/sh\n' > bin/definitely-not-a-command-xyz && chmod +x bin/definitely-not-a-command-xyz
    PATH="$PWD/bin:$PATH" bash "$f" --name nix 2> ok.txt
    expect_contains ok.txt "hello nix"
  '';
}
