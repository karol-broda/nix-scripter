{
  lib,
  scripter,
  runTest,
  failsToEvaluate,
  ...
}:
let
  bash = module: scripter.bash ({ name = "x"; } // module);

  shouldFail = {
    feature-not-enabled = bash { text = "ui::info hi"; };
    unknown-function = bash {
      features.ui = true;
      text = "ui::infoo hi";
    };
    capability-missing = bash {
      features.ctx = true;
      bash.target = "3.2";
      text = "declare -A i; ctx::info -v i";
    };
    assoc-on-3_2 = bash {
      bash.target = "3.2";
      args.vars.style = "assoc";
      args.flags.a = { };
      text = "true";
    };
    both-text-and-src = bash {
      text = "true";
      src = ./fixtures/fails.sh;
    };
    duplicate-short = bash {
      args.flags.a.short = "x";
      args.flags.b.short = "x";
      text = "true";
    };
    disabled-dependency = bash {
      features.ui = true;
      features.core = false;
      text = "true";
    };
  };

  unexpectedlyEvaluated = lib.attrNames (lib.filterAttrs (_: drv: !failsToEvaluate drv) shouldFail);
in
{
  eval-failures = runTest "eval-failures" [ ] (
    if unexpectedlyEvaluated == [ ] then
      "true"
    else
      "fail 'expected evaluation errors for: ${lib.concatStringsSep ", " unexpectedlyEvaluated}'"
  );
}
