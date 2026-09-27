{
  lib,
  pkgs,
  config,
  context,
  cli,
  files,
  checks,
  layout,
  extend,
}:
let
  inherit (context) name standalone;
  inherit (import ../util.nix { inherit lib; }) joinLines;
  completions = import ../../args/completions { inherit lib; };

  completionFiles = lib.optionalAttrs cli.enable {
    "share/bash-completion/completions/${name}" = completions.bash cli.ir;
    "share/zsh/site-functions/_${name}" = completions.zsh cli.ir;
    "share/fish/vendor_completions.d/${name}.fish" = completions.fish cli.ir;
  };

  attrFor = path: "completion_" + lib.replaceStrings [ "/" "." "-" "+" ] [ "_" "_" "_" "_" ] path;

  installCompletion = path: ''
    mkdir -p $out/${dirOf path}
    cp "''$${attrFor path}Path" $out/${path}
  '';

  rejectStorePaths = ''
    if grep -n '/nix/store/' $out/bin/${name} >&2; then
      echo "${name}: standalone script contains /nix/store paths (see lines above)" >&2
      exit 1
    fi
  '';

  package =
    pkgs.runCommandLocal name
      (
        {
          nativeBuildInputs = lib.unique (lib.concatMap (r: r.packages) checks.build);
          passAsFile = map attrFor (lib.attrNames completionFiles);
          passthru = {
            inherit config extend;
            inherit (layout) sourceMap;
            source = files.source;
            sourceMapFile = files.sourceMap;
            checks = checks.derivations;
            argsIR = if cli.enable then cli.ir else null;
            app = {
              type = "app";
              program = "${package}/bin/${name}";
              meta.description = config.description;
            };
          }
          // config.passthru;
          meta = {
            mainProgram = name;
          }
          // lib.optionalAttrs (config.description != "") { inherit (config) description; }
          // config.meta;
        }
        // lib.mapAttrs' (path: text: lib.nameValuePair (attrFor path) text) completionFiles
        // lib.optionalAttrs standalone { allowedReferences = [ ]; }
      )
      ''
        mkdir -p $out/bin
        cp ${files.source} $out/bin/${name}
        chmod 755 $out/bin/${name}
        ${lib.optionalString standalone rejectStorePaths}
        ${joinLines (map (r: r.script) checks.build)}
        ${joinLines (map installCompletion (lib.attrNames completionFiles))}
      '';
in
package
