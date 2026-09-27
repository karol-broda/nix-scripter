{
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
}
