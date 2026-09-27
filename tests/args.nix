{
  pkgs,
  lib,
  scripter,
  runTest,
  ...
}:
let
  argsScript = scripter.bash ./scripts/args-demo.nix;
  commandsScript = scripter.bash ./scripts/commands.nix;
in
{
  args = argsScript.checks.args;
  commands = commandsScript.checks.args;

  args-run = runTest "args-run" [ ] ''
    res=$(${argsScript}/bin/args-demo prod --tag a --tag b)
    [ "$res" = "env=prod timeout=30 tags=a b" ] || fail "unexpected: $res"
    test -f ${argsScript}/share/bash-completion/completions/args-demo
    test -f ${argsScript}/share/zsh/site-functions/_args-demo
    test -f ${argsScript}/share/fish/vendor_completions.d/args-demo.fish
  '';
  completions =
    runTest "completions"
      [
        pkgs.bash
        pkgs.zsh
        pkgs.fish
      ]
      ''
        for s in ${argsScript} ${commandsScript}; do
          for f in $s/share/bash-completion/completions/*; do bash -n "$f"; done
          for f in $s/share/zsh/site-functions/*; do zsh -n "$f"; done
          for f in $s/share/fish/vendor_completions.d/*; do HOME=$TMPDIR fish -n "$f"; done
        done
        cat > complete.bash <<'EOF'
        set -eu
        source ${commandsScript}/share/bash-completion/completions/cmds
        complete_words() {
          COMP_WORDS=("$@")
          COMP_CWORD=$(($# - 1))
          _cmds_complete
          echo "''${COMPREPLY[*]}"
        }
        [ "$(complete_words cmds db mi)" = migrate ]
        [ "$(complete_words cmds st --j)" = --json ]
        EOF
        ${pkgs.bashInteractive}/bin/bash complete.bash || fail "bash completion"
      '';
  commands-run = runTest "commands-run" [ ] ''
    res=$(${commandsScript}/bin/cmds status --json)
    [ "$res" = "$(printf 'setup runs first\nstatus json=1 dry= cmd=status')" ] || fail "status: $res"
    res=$(${commandsScript}/bin/cmds db migrate)
    [ "$res" = "$(printf 'setup runs first\nmigrating 1 steps')" ] || fail "migrate: $res"
    ${commandsScript}/bin/cmds db --help | grep -q "migrate  Run migrations" || fail "db help"
  '';
}
