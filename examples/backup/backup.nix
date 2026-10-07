{ pkgs, ... }:
{
  lang = "bash";
  description = "Back up directories with restic";
  version = "1.0.0";
  src = ./backup.sh;
  deps = [
    pkgs.restic
    pkgs.jq
  ];

  args = {
    globals.dryRun = true;

    options.repo = {
      short = "r";
      env = "RESTIC_REPOSITORY";
      required = true;
      description = "Repository location";
    };
    options.password-file = {
      short = "p";
      type = "file";
      env = "RESTIC_PASSWORD_FILE";
      required = true;
      description = "File containing the repository password";
    };

    commands.init.description = "Create a new repository";

    commands.run = {
      description = "Back up paths (default: $HOME)";
      positional = [
        {
          name = "paths";
          type = "path";
          variadic = true;
        }
      ];
      options.tag = {
        repeated = true;
        description = "Tag the snapshot (repeatable)";
      };
      flags.one-file-system = {
        short = "x";
        description = "Do not cross filesystem boundaries";
      };
    };

    commands.list = {
      description = "List snapshots";
      aliases = [ "ls" ];
      options.tag = {
        repeated = true;
        description = "Only snapshots with this tag";
      };
      flags.json.description = "Print restic's JSON to stdout";
    };

    commands.restore = {
      description = "Restore a snapshot";
      positional = [
        {
          name = "snapshot";
          optional = true;
          default = "latest";
        }
      ];
      options.target = {
        short = "t";
        type = "path";
        required = true;
        description = "Directory to restore into";
      };
    };

    commands.prune = {
      description = "Apply the retention policy and free space";
      options = {
        keep-daily = {
          type = "int";
          default = 7;
        };
        keep-weekly = {
          type = "int";
          default = 4;
        };
        keep-monthly = {
          type = "int";
          default = 12;
        };
      };
    };

    examples = [
      {
        cmd = "backup -r /mnt/backup -p ~/.restic-pass run ~/Documents --tag docs";
        description = "Back up documents to an external disk";
      }
      {
        cmd = "backup ls --tag docs";
        description = "Repository from RESTIC_REPOSITORY / RESTIC_PASSWORD_FILE";
      }
    ];

    tests = [
      {
        argv = [
          "-r"
          "/srv/repo"
          "run"
          "a"
          "b"
          "--tag"
          "nightly"
          "-x"
        ];
        env.RESTIC_PASSWORD_FILE = "/etc/passwd";
        expect = {
          _command = "run";
          repo = "/srv/repo";
          paths = [
            "a"
            "b"
          ];
          tag = [ "nightly" ];
          one_file_system = true;
        };
      }
      {
        argv = [
          "restore"
          "--target"
          "/tmp/out"
        ];
        env = {
          RESTIC_REPOSITORY = "/srv/repo";
          RESTIC_PASSWORD_FILE = "/etc/passwd";
        };
        expect = {
          snapshot = "latest";
          target = "/tmp/out";
        };
      }
      {
        argv = [ "ls" ];
        exitCode = 2;
        env.RESTIC_PASSWORD_FILE = "/etc/passwd";
        stderrContains = "missing required option '--repo'";
      }
    ];
  };
}
