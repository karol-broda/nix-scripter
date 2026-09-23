# Test suite, exposed as flake `checks`. Each test builds scripts with the
# library and runs them under controlled environments.
{ pkgs, scripterLib }:
let
  inherit (pkgs) lib;
  scripter = scripterLib.mkScripter { inherit pkgs; };

  # Runs `script` with the given packages; fails the check on non-zero exit.
  test =
    name: packages: script:
    pkgs.runCommandLocal "test-${name}"
      {
        nativeBuildInputs = [
          pkgs.gnugrep
          pkgs.diffutils
        ]
        ++ packages;
      }
      ''
        set -euo pipefail
        fail() { echo "FAIL: $*" >&2; exit 1; }
        expect_contains() { grep -qF -- "$2" "$1" || { echo "--- $1:" >&2; cat "$1" >&2; fail "$1 does not contain: $2"; }; }
        expect_not_contains() { if grep -qF -- "$2" "$1"; then cat "$1" >&2; fail "$1 contains: $2"; fi; }
        ${script}
        touch $out
      '';

  # Asserts that building a script fails at evaluation time.
  evalFails = name: drv: {
    inherit name;
    failed = !(builtins.tryEval (builtins.seq drv.drvPath true)).success;
  };

  uiScript = scripter.bash {
    name = "ui-demo";
    features.ui = true;
    text = ''
      ui::header "Header"
      ui::section "Section"
      ui::info "an info"
      ui::debug "a debug"
      ui::warn "a warning"
      ui::error "an error"
      ui::success "a success"
      ui::kv key value
      ui::list one two
      ui::group_begin "Group"
      ui::info "inside"
      ui::group_end
      ui::group "Command group" -- echo "from command"
      ui::annotate warning "check this" src/main.c 42
      ui::mask "s3cret"
      printf 'a\tbb\nccc\td\n' | ui::table
      ui::spin "Spinning" -- true
      ui::progress 5 10 "Copying"
      ui::progress 10 10 "Copying"
      echo "stdout stays clean"
    '';
  };

  argsScript = scripter.bash {
    name = "args-demo";
    version = "1.2.3";
    description = "Exercise the argument parser";
    args = {
      globals = {
        verbose = true;
        yes = true;
        color = true;
      };
      flags.force = {
        short = "f";
        description = "Skip confirmation";
        env = "DEMO_FORCE";
      };
      flags.watch = {
        short = "w";
        negatable = true;
      };
      flags.level = {
        short = "l";
        count = true;
      };
      options.timeout = {
        short = "t";
        type = "int";
        default = 30;
        env = "DEMO_TIMEOUT";
      };
      options.tag = {
        repeated = true;
        description = "Tag (repeatable)";
      };
      options.format = {
        values = [
          "json"
          "text"
        ];
        default = "text";
      };
      options.name.pattern = "^[a-z]+$";
      options.ratio.type = "float";
      options.interactive.type = "bool";
      positional = [
        {
          name = "env";
          values = [
            "staging"
            "prod"
          ];
        }
        {
          name = "extra";
          variadic = true;
          optional = true;
        }
      ];
      constraints = [
        {
          exclusive = [
            "force"
            "interactive"
          ];
        }
        { requires.ratio = [ "name" ]; }
      ];
      tests = [
        {
          argv = [
            "prod"
            "-f"
          ];
          expect = {
            env = "prod";
            force = true;
            timeout = 30;
            format = "text";
            tag = [ ];
            extra = [ ];
          };
        }
        {
          argv = [
            "staging"
            "--tag"
            "a"
            "--tag=b"
            "-t5"
            "x"
            "y"
          ];
          expect = {
            tag = [
              "a"
              "b"
            ];
            timeout = 5;
            extra = [
              "x"
              "y"
            ];
          };
        }
        {
          argv = [
            "prod"
            "-fll"
            "-l"
            "-w"
            "--no-watch"
          ];
          expect = {
            force = true;
            level = 3;
            watch = false;
          };
        }
        {
          argv = [
            "prod"
            "--"
            "-not-an-option"
          ];
          expect.extra = [ "-not-an-option" ];
        }
        {
          argv = [ "prod" ];
          env = {
            DEMO_TIMEOUT = "7";
            DEMO_FORCE = "yes";
          };
          expect = {
            timeout = 7;
            force = true;
          };
        }
        {
          argv = [
            "prod"
            "--format"
            "jsn"
          ];
          exitCode = 2;
          stderrContains = "did you mean 'json'";
        }
        {
          argv = [
            "prod"
            "--forse"
          ];
          exitCode = 2;
          stderrContains = "did you mean '--force'";
        }
        {
          argv = [
            "prod"
            "-t"
            "abc"
          ];
          exitCode = 2;
          stderrContains = "expected an integer";
        }
        {
          argv = [
            "prod"
            "--name"
            "Bad1"
          ];
          exitCode = 2;
          stderrContains = "must match";
        }
        {
          argv = [
            "prod"
            "-f"
            "--interactive"
          ];
          exitCode = 2;
          stderrContains = "only one of";
        }
        {
          argv = [
            "prod"
            "--ratio"
            "0.5"
          ];
          exitCode = 2;
          stderrContains = "requires '--name'";
        }
        {
          argv = [ ];
          exitCode = 2;
          stderrContains = "missing required argument <env>";
        }
        {
          argv = [ "--help" ];
          stdoutContains = "Usage: args-demo [OPTIONS] <env> [extra]...";
        }
        {
          argv = [ "--version" ];
          stdoutContains = "args-demo 1.2.3";
        }
        {
          argv = [
            "prod"
            "-vv"
            "--yes"
          ];
          expect = {
            verbose = 2;
            yes = true;
          };
        }
      ];
    };
    text = ''
      printf 'env=%s timeout=%s tags=%s\n' "''${args[env]}" "''${args[timeout]}" "''${args_tag[*]-}"
    '';
  };

  commandsScript = scripter.bash {
    name = "cmds";
    args = {
      globals.verbose = true;
      flags.dry = {
        short = "n";
        description = "Dry run";
      };
      commands.status = {
        description = "Show status";
        aliases = [ "st" ];
        flags.json = { };
        text = ''
          echo "status json=''${args[json]} dry=''${args[dry]} cmd=''${args[_command]}"
        '';
      };
      commands.db = {
        description = "Database commands";
        commands.migrate = {
          description = "Run migrations";
          positional = [
            {
              name = "steps";
              type = "int";
              optional = true;
              default = 1;
            }
          ];
        };
      };
      tests = [
        {
          argv = [
            "st"
            "--json"
            "-n"
          ];
          expect = {
            _command = "status";
            json = true;
            dry = true;
          };
        }
        {
          argv = [
            "db"
            "migrate"
            "3"
          ];
          expect = {
            _command = "db migrate";
            steps = 3;
          };
        }
        {
          argv = [ "stauts" ];
          exitCode = 2;
          stderrContains = "did you mean 'status'";
        }
        {
          argv = [ "db" ];
          exitCode = 2;
          stderrContains = "missing command";
        }
      ];
    };
    text = ''
      echo "setup runs first"
      cmd::db::migrate() {
        echo "migrating ''${args[steps]} steps"
      }
    '';
  };

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

  errorScript = scripter.bash {
    name = "fails";
    features.core = true;
    src = ./fixtures/fails.sh;
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

  generated = scripter.args.generate {
    name = "handwritten";
    spec = ./fixtures/args.toml;
  };

  discovered = scripter.discover { dir = ./fixtures/scripts; };
  discoveredPkgs = lib.mapAttrs (_: m: scripter.mkScript m) discovered;

  evalFailures = [
    (evalFails "feature-not-enabled" (
      scripter.bash {
        name = "x";
        text = "ui::info hi";
      }
    ))
    (evalFails "unknown-function" (
      scripter.bash {
        name = "x";
        features.ui = true;
        text = "ui::infoo hi";
      }
    ))
    (evalFails "capability-missing" (
      scripter.bash {
        name = "x";
        features.ctx = true;
        bash.target = "3.2";
        text = "declare -A i; ctx::info -v i";
      }
    ))
    (evalFails "assoc-on-3.2" (
      scripter.bash {
        name = "x";
        bash.target = "3.2";
        args.vars.style = "assoc";
        args.flags.a = { };
        text = "true";
      }
    ))
    (evalFails "both-text-and-src" (
      scripter.bash {
        name = "x";
        text = "true";
        src = ./fixtures/fails.sh;
      }
    ))
    (evalFails "duplicate-short" (
      scripter.bash {
        name = "x";
        args.flags.a.short = "x";
        args.flags.b.short = "x";
        text = "true";
      }
    ))
    (evalFails "disabled-dependency" (
      scripter.bash {
        name = "x";
        features.ui = true;
        features.core = false;
        text = "true";
      }
    ))
  ];
in
{
  minimal = test "minimal" [ ] ''
    res=$(${
      scripter.bash {
        name = "hello";
        deps = [ pkgs.hello ];
        text = ''hello -g "hi $1"'';
      }
    }/bin/hello there)
    [ "$res" = "hi there" ] || fail "unexpected output: $res"
  '';

  ui-plain = test "ui-plain" [ ] ''
    ${uiScript}/bin/ui-demo > stdout.txt 2> stderr.txt
    [ "$(cat stdout.txt)" = "$(printf 'from command\nstdout stays clean')" ] || fail "stdout polluted: $(cat stdout.txt)"
    for line in "== Header ==" "-- Section" "[info] an info" "[warn] a warning" \
      "[error] an error" "[ok] a success" "  - one" "==> Group" "==> Command group" \
      "[warn] check this (src/main.c:42)" "[info] Spinning ..." "[ok] Spinning" \
      "[info] Copying: 50%" "[info] Copying: 100%"; do
      expect_contains stderr.txt "$line"
    done
    expect_not_contains stderr.txt "a debug"
    expect_not_contains stderr.txt "s3cret"
    printf 'a\tbb\nccc\td\n' > table.txt
    grep -qF "$(printf 'ccc\td')" stderr.txt || fail "plain table is not TSV"

    SCRIPTER_LOG_LEVEL=debug ${uiScript}/bin/ui-demo 2> debug.txt > /dev/null
    expect_contains debug.txt "[debug] a debug"
    SCRIPTER_LOG_LEVEL=warn ${uiScript}/bin/ui-demo 2> warn.txt > /dev/null
    expect_not_contains warn.txt "an info"
    expect_contains warn.txt "a warning"
  '';

  ui-github = test "ui-github" [ ] ''
    GITHUB_ACTIONS=true ${uiScript}/bin/ui-demo 2> gh.txt > /dev/null
    for line in "::warning::a warning" "::error::an error" "::group::Group" "::endgroup::" \
      "::group::Command group" "::warning file=src/main.c,line=42::check this" "::add-mask::s3cret"; do
      expect_contains gh.txt "$line"
    done
    expect_contains gh.txt "$(printf '\e[34m')"
    NO_COLOR=1 GITHUB_ACTIONS=true ${uiScript}/bin/ui-demo 2> nocolor.txt > /dev/null
    expect_not_contains nocolor.txt "$(printf '\e[')"
  '';

  ui-other-ci = test "ui-other-ci" [ ] ''
    GITLAB_CI=true ${uiScript}/bin/ui-demo 2> gitlab.txt > /dev/null
    expect_contains gitlab.txt "section_start:"
    expect_contains gitlab.txt "[collapsed=true]"
    expect_contains gitlab.txt "section_end:"
    TF_BUILD=True ${uiScript}/bin/ui-demo 2> azure.txt > /dev/null
    expect_contains azure.txt "##vso[task.logissue type=warning]a warning"
    expect_contains azure.txt "##[group]Group"
    TEAMCITY_VERSION=1 ${uiScript}/bin/ui-demo 2> tc.txt > /dev/null
    expect_contains tc.txt "##teamcity[blockOpened name='Group']"
    SCRIPTER_CI=none GITHUB_ACTIONS=true ${uiScript}/bin/ui-demo 2> forced.txt > /dev/null
    expect_contains forced.txt "[warn] a warning"
  '';

  ui-fancy = test "ui-fancy" [ pkgs.util-linux ] ''
    script -qec "${uiScript}/bin/ui-demo" /dev/null > tty.txt
    expect_contains tty.txt "$(printf '\e[1m')"
    expect_contains tty.txt "an info"
    SCRIPTER_ICONS=unicode script -qec "${uiScript}/bin/ui-demo" /dev/null > unicode.txt
    expect_contains unicode.txt "✔"
  '';

  args = argsScript.checks.args;

  args-run = test "args-run" [ ] ''
    res=$(${argsScript}/bin/args-demo prod --tag a --tag b)
    [ "$res" = "env=prod timeout=30 tags=a b" ] || fail "unexpected: $res"
    test -f ${argsScript}/share/bash-completion/completions/args-demo
    test -f ${argsScript}/share/zsh/site-functions/_args-demo
    test -f ${argsScript}/share/fish/vendor_completions.d/args-demo.fish
  '';

  completions =
    test "completions"
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

  commands = commandsScript.checks.args;

  commands-run = test "commands-run" [ ] ''
    res=$(${commandsScript}/bin/cmds status --json)
    [ "$res" = "$(printf 'setup runs first\nstatus json=1 dry= cmd=status')" ] || fail "status: $res"
    res=$(${commandsScript}/bin/cmds db migrate)
    [ "$res" = "$(printf 'setup runs first\nmigrating 1 steps')" ] || fail "migrate: $res"
    ${commandsScript}/bin/cmds db --help | grep -q "migrate  Run migrations" || fail "db help"
  '';

  standalone = test "standalone" [ pkgs.jq ] ''
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

  errors = test "errors" [ ] ''
    rc=0
    ${errorScript}/bin/fails 2> err.txt || rc=$?
    [ "$rc" -eq 3 ] || fail "expected exit 3, got $rc"
    expect_contains err.txt "fails: error: command failed with exit code 3"
    expect_contains err.txt "at inner (fails.sh:3)"
    expect_contains err.txt "at outer (fails.sh:7)"
    expect_contains err.txt "at main (fails.sh:10)"
    expect_contains err.txt "cleanup ran"
  '';

  compat-3_2 = test "compat-3_2" [ ] ''
    grep -q 'ARG_X=' ${compat}/bin/compat || fail "3.2 target should use globals"
    ! grep -q 'declare -A args' ${compat}/bin/compat || fail "3.2 target declared an assoc array"
    ${compat}/bin/compat 2> out.txt
    expect_contains out.txt "x=1"
  '';

  generate = test "generate" [ ] ''
    cat > handwritten.sh <<'EOF'
    set -euo pipefail
    source ${generated}/parser.bash
    args_parse "$@"
    echo "greeting=''${args[greeting]} loud=''${args[loud]}"
    EOF
    res=$(bash handwritten.sh --loud)
    [ "$res" = "greeting=hello loud=1" ] || fail "unexpected: $res"
    expect_contains ${generated}/help.txt "Usage: handwritten [OPTIONS]"
    test -f ${generated}/completions/_handwritten
  '';

  discover = test "discover" [ ] ''
    ${discoveredPkgs.greet}/bin/greet > greet.txt
    expect_contains greet.txt "hello from discovered"
    ${discoveredPkgs.tool}/bin/tool > tool.txt
    expect_contains tool.txt "tool main"
    ${lib.optionalString (discovered ? _ignored) "fail '_ignored was discovered'"}
  '';

  eval-failures =
    let
      unexpected = lib.filter (t: !t.failed) evalFailures;
    in
    test "eval-failures" [ ] (
      if unexpected == [ ] then
        "true"
      else
        "fail 'expected evaluation errors for: ${lib.concatMapStringsSep ", " (t: t.name) unexpected}'"
    );
}
