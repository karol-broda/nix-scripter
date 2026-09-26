{ lib }:
let
  inherit (import ./argument.nix { inherit lib; }) mkArgument;
  inherit (import ./naming.nix { inherit lib; }) sanitize;

  global =
    fields:
    mkArgument (
      fields
      // {
        key = sanitize fields.name;
        long = fields.name;
      }
    );

  definitions = {
    verbose = global {
      kind = "flag";
      name = "verbose";
      short = "v";
      count = true;
      description = "Increase verbosity (repeatable)";
      action = "verbose";
    };
    quiet = global {
      kind = "flag";
      name = "quiet";
      short = "q";
      description = "Only print warnings and errors";
      action = "quiet";
    };
    yes = global {
      kind = "flag";
      name = "yes";
      short = "y";
      description = "Answer yes to all confirmations";
      action = "yes";
    };
    dryRun = global {
      kind = "flag";
      name = "dry-run";
      description = "Print what would be done without doing it";
      action = "dryRun";
    };
    color = global {
      kind = "option";
      name = "color";
      type = "enum";
      values = [
        "auto"
        "always"
        "never"
      ];
      metavar = "WHEN";
      description = "When to use colors";
      action = "color";
    };
  };
in
{
  enabled = globals: lib.attrValues (lib.filterAttrs (name: _: globals.${name} or false) definitions);
}
