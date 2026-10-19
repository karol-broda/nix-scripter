# nix-scripter

A Nix library for writing shell scripts. It generates argument parsers from a
spec written in Nix and ships a small runtime library for terminal and CI
output. Scripts are either linked against the Nix store or built as standalone
files.

```nix
scripter.bash {
  name = "greet";
  imports = [ scripter.presets.recommended ];
  args.options.name = { short = "n"; default = "world"; };
  text = ''
    ui::success "hello, ''${args[name]}"
  '';
}
```

```console
$ greet --name nix
✔ hello, nix
$ greet --nmae nix
greet: error: unrecognized option '--nmae'

  tip: did you mean '--name'?

Try 'greet --help' for more information.
```

> [!NOTE]
> nix-scripter is early. Bash is the only backend so far and the API may still
> change.

## Overview

- Arguments are declared in Nix. The generated parser handles help text,
  subcommands, validation and suggestions for mistyped options, and completions
  are generated for bash, zsh and fish.
- The `ui::` functions print colored output with spinners in a terminal and
  plain lines otherwise. In GitHub Actions, GitLab CI and a few other CI
  systems they use the native log groups and annotations.
- Linked scripts get their dependencies from the Nix store. Standalone scripts
  contain no store paths and need bash 3.2 or newer.
- The generated script is checked with `bash -n` and ShellCheck during the
  build. Calls to library functions that don't exist are build errors.
- Without further configuration a script behaves much like one from
  `writeShellApplication`. Library features and extra flags are off until
  enabled, and presets enable common sets of them.

## Getting started

Add the flake-parts module and declare scripts per system.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    scripter.url = "github:karol-broda/nix-scripter";
    scripter.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{ flake-parts, scripter, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ scripter.flakeModules.default ];
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];

      scripter.defaults = scripter.lib.presets.recommended;

      perSystem = { pkgs, ... }: {
        scripter.scripts.deploy = {
          lang = "bash";
          src = ./scripts/deploy.sh;
          deps = [ pkgs.jq ];
        };

        scripter.discover = {
          enable = true;
          dir = ./scripts;
        };
      };
    };
}
```

Each script is exposed as a package, an app and a set of checks.

<details>
<summary>Without flake-parts or without flakes</summary>

```nix
# in a flake
scripter = inputs.scripter.lib.mkScripter { inherit pkgs; };

# through the overlay
pkgs = import nixpkgs { overlays = [ inputs.scripter.overlays.default ]; };

# without flakes
scripter = import (fetchTarball "https://github.com/karol-broda/nix-scripter/archive/master.tar.gz") {
  inherit pkgs;
};
```

</details>

## Writing scripts

A script is a module. Its source is either inline `text` or a file in `src`.

```nix
scripter.bash {
  name = "backup";
  description = "Back up directories with restic";
  src = ./backup.sh;
  deps = [ pkgs.restic pkgs.jq ];
  features.ui = true;

  args = {
    globals.dryRun = true;
    options.repo = { short = "r"; env = "RESTIC_REPOSITORY"; required = true; };
    commands.run = {
      positional = [ { name = "paths"; type = "path"; variadic = true; } ];
      options.tag.repeated = true;
    };
    commands.list.flags.json = { };
  };
}
```

The script reads values from `args[...]` and implements the subcommands as
`cmd::run` and `cmd::list` functions.

### Presets

| Preset | Effect |
|---|---|
| `recommended` | UI with unicode icons and the `--verbose`, `--quiet`, `--color` and `--yes` flags |
| `portable` | Standalone script for bash 3.2 and newer |
| `hermetic` | Only Nix-provided commands on `PATH` |
| `small` | Leaves out library functions the script never calls |
| `strict` | Stricter ShellCheck plus an shfmt check |

### Library

Features are off until a script enables them.

| Feature | Provides |
|---|---|
| `core` | `die`, `on_exit`, `run`, `need_cmd` and readable error traces |
| `ctx` | Detection of CI, terminals, colors and the platform |
| `ui` | Messages, headings, tables, progress bars, spinners, groups, prompts and CI annotations |

Output goes to stderr, so stdout stays free for data.

## Examples

- [`showcase`](examples/showcase) prints everything the `ui` feature can
  render. Run it with `nix run ./examples/showcase`.
- [`backup`](examples/backup) is a small backup tool built on restic.
- [`full`](examples/full) uses most options in a single flake.

## Development

```console
$ nix flake check
$ nix flake check ./examples/backup
$ nix fmt
```

The repository has a dev shell and an `.envrc` for direnv.

## License

Copyright © 2026 Karol Broda. Licensed under the [EUPL-1.2](LICENSE).
