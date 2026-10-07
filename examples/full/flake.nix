{
  description = "nix-scripter example using every feature the library offers";

  inputs = {
    scripter.url = "path:../..";
    nixpkgs.follows = "scripter/nixpkgs";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, scripter, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ scripter.flakeModules.default ];

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      # Shared by every system and every script.
      scripter = {
        extensions = [ (import ./extensions { inherit (inputs.nixpkgs) lib; }) ];
        defaults =
          { scripter, ... }:
          {
            imports = [ scripter.presets.team ];
            version = "1.4.0";
          };
        scripts.doctor = {
          lang = "bash";
          description = "Show what the environment looks like to scripts";
          src = ./src/doctor.sh;
          features.git.enable = false;
        };
      };

      perSystem =
        {
          config,
          pkgs,
          lib,
          scripter,
          ...
        }:
        {
          scripter = {
            discover = {
              enable = true;
              dir = ./scripts;
            };

            expose.default = "deploy";

            scripts.deploy = {
              lang = "bash";
              description = "Deploy services to an environment";
              src = ./src/deploy.sh;
              deps = [
                pkgs.jq
                {
                  pkg = pkgs.coreutils;
                  commands = [
                    "sleep"
                    "touch"
                  ];
                }
              ];
              env.DEPLOY_REGISTRY = "registry.example.invalid";
              features.ui = {
                kvWidth = 12;
                theme.success = "bright-green";
              };
              features.git.enable = false;

              args = {
                globals = {
                  verbose = true;
                  quiet = true;
                  color = true;
                  yes = true;
                  dryRun = true;
                };

                positional = [
                  {
                    name = "env";
                    values = [
                      "staging"
                      "prod"
                    ];
                    description = "Target environment";
                  }
                  {
                    name = "services";
                    variadic = true;
                    optional = true;
                    description = "Services to deploy (default: all)";
                  }
                ];

                flags.force = {
                  short = "f";
                  env = "DEPLOY_FORCE";
                  description = "Skip the production confirmation";
                };

                options = {
                  app = {
                    short = "a";
                    default = "shop";
                    pattern = "^[a-z][a-z0-9-]*$";
                    description = "Application name";
                  };
                  release = {
                    env = "DEPLOY_RELEASE";
                    default = "latest";
                    description = "Release to deploy";
                  };
                  replicas = {
                    short = "r";
                    type = "int";
                    default = 3;
                    description = "Number of replicas";
                  };
                  canary = {
                    type = "float";
                    metavar = "SHARE";
                    description = "Route this share of traffic to the new version";
                  };
                  wait = {
                    type = "bool";
                    default = true;
                    negatable = true;
                    description = "Wait for the rollout to finish";
                  };
                  label = {
                    short = "l";
                    repeated = true;
                    metavar = "KEY=VALUE";
                    description = "Label to attach (repeatable)";
                  };
                  region = {
                    values = [
                      "eu-west"
                      "us-east"
                    ];
                    complete = "printf '%s\\n' eu-west us-east";
                    description = "Region (completed dynamically)";
                  };
                  manifest = {
                    type = "file";
                    hidden = true;
                    description = "Use an existing manifest";
                  };
                };

                constraints = [
                  {
                    exclusive = [
                      "canary"
                      "force"
                    ];
                  }
                  { requires.canary = [ "release" ]; }
                ];

                groups."Rollout options" = [
                  "replicas"
                  "canary"
                  "wait"
                ];

                examples = [
                  {
                    cmd = "deploy staging api web";
                    description = "Deploy two services to staging";
                  }
                  {
                    cmd = "deploy prod --release 2.1.0 --canary 0.1";
                    description = "Canary release to production";
                  }
                ];

                tests = [
                  {
                    argv = [
                      "staging"
                      "api"
                      "web"
                      "-l"
                      "team=core"
                      "--no-wait"
                    ];
                    expect = {
                      env = "staging";
                      services = [
                        "api"
                        "web"
                      ];
                      label = [ "team=core" ];
                      wait = false;
                      replicas = 3;
                    };
                  }
                  {
                    argv = [ "prod" ];
                    env.DEPLOY_RELEASE = "2.0.0";
                    expect.release = "2.0.0";
                  }
                  {
                    argv = [
                      "prod"
                      "--canary"
                      "0.2"
                      "-f"
                    ];
                    exitCode = 2;
                    stderrContains = "only one of";
                  }
                  {
                    argv = [
                      "qa"
                    ];
                    exitCode = 2;
                    stderrContains = "possible values: staging prod";
                  }
                ];
              };
            };

            scripts.release = {
              lang = "bash";
              description = "Prepare and publish releases";
              src = ./src/release/main.sh;
              features.git.remote = "upstream";
              args = {
                commands = {
                  prepare = {
                    description = "Tag a new release";
                    aliases = [ "prep" ];
                    positional = [
                      {
                        name = "version";
                        pattern = "^[0-9]+\\.[0-9]+\\.[0-9]+$";
                        description = "Semantic version";
                      }
                    ];
                    src = ./src/release/prepare.sh;
                  };
                  publish = {
                    description = "Push the release tags";
                    flags.draft.description = "Publish as a draft";
                  };
                  notes = {
                    description = "Release notes";
                    commands.show.description = "Show the files changed since the last tag";
                  };
                  self-test = {
                    hidden = true;
                    inheritGlobals = false;
                    text = ''
                      ui::success "release tooling works"
                    '';
                  };
                };
                tests = [
                  {
                    argv = [
                      "prep"
                      "1.2.3"
                      "--dry-run"
                    ];
                    expect = {
                      _command = "prepare";
                      version = "1.2.3";
                      dry_run = true;
                    };
                  }
                  {
                    argv = [
                      "prepare"
                      "v1"
                    ];
                    exitCode = 2;
                    stderrContains = "must match";
                  }
                  {
                    argv = [
                      "notes"
                      "show"
                      "-v"
                    ];
                    expect._command = "notes show";
                  }
                ];
              };
            };

            scripts.install = {
              imports = [ scripter.presets.portable ];
              lang = "bash";
              description = "Standalone installer that runs on bash 3.2 (macOS)";
              src = ./src/install.sh;
              deps = [ pkgs.curl ];
              requires = [ "id" ];
              features.git.enable = false;
              args.options = {
                release = {
                  default = "1.4.0";
                  description = "Release to install";
                };
                prefix = {
                  type = "dir";
                  default = "/usr/local";
                  description = "Installation prefix";
                };
                system.type = "bool";
              };
            };

            scripts.hermetic = {
              imports = [ scripter.presets.hermetic ];
              lang = "bash";
              description = "Only sees the tools Nix gives it";
              src = ./src/hermetic.sh;
              deps = [ pkgs.jq ];
              features.git.enable = false;
            };

            scripts.strict = {
              imports = [ scripter.presets.strict ];
              lang = "bash";
              description = "Checked with shellcheck at style level and shfmt";
              src = ./src/strict.sh;
              features.git.enable = false;
              check.shellcheck.exclude = [ "SC2317" ];
            };

            scripts.mac-only = {
              lang = "bash";
              description = "Only exposed on darwin systems";
              text = ''ui::info "running on $(ctx::os)"'';
              features.git.enable = false;
              meta.platforms = lib.platforms.darwin;
            };
          };

          packages.greeter =
            let
              parser = scripter.args.generate {
                name = "greeter";
                version = "1.0.0";
                spec = ./src/greeter-args.toml;
              };
            in
            pkgs.writeShellApplication {
              name = "greeter";
              excludeShellChecks = [
                "SC1091"
                "SC2154"
              ];
              text = ''
                # shellcheck source=/dev/null
                source ${parser}/parser.bash
                args_parse "$@"
                for _ in $(seq "''${args[times]}"); do
                  echo "''${args[greeting]}, ''${args[name]}!"
                done
              '';
            };

          devShells.default = pkgs.mkShellNoCC {
            packages = lib.attrValues config.scripter.packages;
          };
        };
    };
}
