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

  compat = scripter.bash {
    name = "compat";
    bash.target = "3.2";
    features.ui = true;
    args.options.x.default = "1";
    text = ''
      ui::info "x=$ARG_X"
      ui::table <<<"a"
    '';
  };
in
{
  standalone = runTest "standalone" [ pkgs.jq ] ''
    f=${standaloneScript}/bin/portable
    ! grep -q /nix/store "$f" || fail "store path in standalone script"
    head -1 "$f" | grep -qx '#!/usr/bin/env bash' || fail "wrong shebang"
    rc=0
    bash "$f" 2> missing.txt || rc=$?
    [ "$rc" -eq 127 ] || fail "expected exit 127, got $rc"
    expect_contains missing.txt "missing required commands: definitely-not-a-command-xyz"
    mkdir bin && printf '#!/bin/sh\n' > bin/definitely-not-a-command-xyz && chmod +x bin/definitely-not-a-command-xyz
    PATH="$PWD/bin:$PATH" bash "$f" --name nix 2> ok.txt
    expect_contains ok.txt "hello nix"
  '';
  compat-3_2 = runTest "compat-3_2" [ ] ''
    grep -q 'ARG_X=' ${compat}/bin/compat || fail "3.2 target should use globals"
    ! grep -q 'declare -A args' ${compat}/bin/compat || fail "3.2 target declared an assoc array"
    ${compat}/bin/compat 2> out.txt
    expect_contains out.txt "x=1"
  '';
}
