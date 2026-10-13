{ lib }:
final: _prev: {
  features.git = {
    description = "Git helpers shared by this team's scripts.";
    namespace = "git";
    requires = [
      "core"
      "ctx"
    ];
    deps = pkgs: [ pkgs.git ];
    commands = [ "git" ];

    options =
      { lib, ... }:
      {
        options.remote = lib.mkOption {
          type = lib.types.str;
          default = "origin";
        };
      };

    functions = {
      branch = { };
      is_clean = { };
      remote_url = { };
      changed_files = {
        tier = "E";
        needs = [ "namerefs" ];
      };
    };

    impl.bash =
      { cfg, ... }:
      ''
        __example_git_remote=${lib.escapeShellArg cfg.remote}
      ''
      + builtins.readFile ./git.bash;
  };

  presets.team = {
    imports = [
      final.presets.recommended
      final.presets.small
    ];
    features.git.enable = lib.mkDefault true;
    features.ui.theme.accent = lib.mkDefault "magenta";
    args.globals.dryRun = lib.mkDefault true;
  };
}
