{
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
}
