# The build pipeline: resolve → generate → assemble → check → emit.
{
  lib,
  pkgs,
  registry,
  config,
  extend,
}:
let
  inherit (lib)
    concatMap
    concatStringsSep
    filter
    length
    optional
    optionals
    ;

  name = config.name;
  backend = registry.backends.${config.lang};
  targetName = backend.targetOf config;
  caps = backend.targets.${targetName}.caps;
  standalone = config.mode == "standalone";

  argsIR = import ../args/ir.nix { inherit lib; };
  completions = import ../args/completions.nix { inherit lib; };

  # -- resolve -------------------------------------------------------------
  user =
    if config.text != null then
      {
        text = config.text;
        file = "<${name}>";
      }
    else
      {
        text = builtins.readFile config.src;
        file = baseNameOf config.src;
      };

  featureNames = lib.attrNames (
    lib.filterAttrs (_: f: f.enable) (removeAttrs config.features [ "_module" ])
  );
  ordered =
    (lib.toposort (a: b: lib.elem a (registry.features.${b}.requires or [ ])) featureNames).result;

  # -- args ----------------------------------------------------------------
  argsEnabled = config.args.enable;
  style =
    if config.args.vars.style != null then config.args.vars.style else backend.argsStyle targetName;
  argsResult = argsIR.ir {
    inherit name style;
    inherit (config) version description;
    spec = config.args;
  };
  ir = argsResult.ir;
  argsCode = backend.argsCodegen { inherit ir; };

  # -- library usage -------------------------------------------------------
  namespaces = lib.listToAttrs (
    lib.mapAttrsToList (fname: f: lib.nameValuePair (f.namespace or fname) fname) registry.features
  );
  userTexts = [ user.text ] ++ optionals argsEnabled (map (b: b.text) argsCode.bodies);
  scanned = lib.unique (concatMap backend.scan userTexts);
  libraryCalls = filter (u: namespaces ? ${u.ns}) scanned;
  bareCalls = concatMap (
    fname:
    let
      bare = lib.attrNames (
        lib.filterAttrs (_: s: s.bare or false) (registry.features.${fname}.functions or { })
      );
    in
    map (fn: {
      feature = fname;
      inherit fn;
    }) (lib.unique (concatMap (backend.scanBare bare) userTexts))
  ) featureNames;

  versionString = t: concatStringsSep "." (map toString t.version);
  sortedTargets = lib.sort (a: b: lib.versionOlder (versionString a.value) (versionString b.value)) (
    lib.mapAttrsToList lib.nameValuePair backend.targets
  );

  callErrors = concatMap (
    call:
    let
      fname = namespaces.${call.ns};
      feature = registry.features.${fname};
      functions = feature.functions or { };
      spec = functions.${call.fn} or null;
      full = backend.naming call.ns call.fn;
      missing = filter (c: !lib.elem c caps) (spec.needs or [ ]);
      candidates = map (backend.naming call.ns) (lib.attrNames functions);
      closest = lib.findFirst (c: lib.strings.levenshteinAtMost 2 full c) null candidates;
      lowest = lib.findFirst (
        t: lib.all (c: lib.elem c t.value.caps) (spec.needs or [ ])
      ) null sortedTargets;
    in
    if !config.features.${fname}.enable then
      [ "`${full}` is used, but features.${fname} is not enabled" ]
    else if spec == null then
      [
        (
          "`${full}` is not a function of the ${fname} feature"
          + lib.optionalString (closest != null) " (did you mean `${closest}`?)"
        )
      ]
    else if missing != [ ] then
      [
        (
          "`${full}` needs ${concatStringsSep ", " missing}, which ${config.lang} target ${targetName} does not have"
          + lib.optionalString (lowest != null) " (lowest target with it: ${lowest.name})"
        )
      ]
    else
      [ ]
  ) libraryCalls;

  usedSpecs =
    map (c: registry.features.${namespaces.${c.ns}}.functions.${c.fn} or { }) libraryCalls
    ++ map (c: registry.features.${c.feature}.functions.${c.fn}) bareCalls;

  # -- dependencies --------------------------------------------------------
  depPackage = d: if lib.isDerivation d then d else d.pkg;
  depCommands =
    d: if lib.isDerivation d then [ (d.meta.mainProgram or (lib.getName d)) ] else d.commands;
  featureDeps = concatMap (f: (registry.features.${f}.deps or (_: [ ])) pkgs) ordered;

  linkedPath = optionals (!standalone) (
    lib.unique (map (p: "${lib.getBin p}/bin") (map depPackage config.deps ++ featureDeps))
  );
  startupCommands = lib.unique (
    config.requires
    ++ optionals standalone (
      concatMap depCommands config.deps
      ++ concatMap (f: registry.features.${f}.commands or [ ]) ordered
      ++ concatMap (s: s.commands or [ ]) usedSpecs
    )
  );

  # -- assemble ------------------------------------------------------------
  features = map (fname: {
    name = fname;
    code =
      let
        impl =
          registry.features.${fname}.impl.${config.lang}
            or (throw "${name}: feature ${fname} has no implementation for ${config.lang}");
      in
      impl {
        cfg = config.features.${fname};
        inherit config caps;
        target = targetName;
        args = if argsEnabled then ir else null;
      };
  }) ordered;

  segments = backend.assemble {
    inherit
      config
      features
      linkedPath
      startupCommands
      user
      ;
    args =
      if argsEnabled then
        {
          inherit ir;
          code = argsCode;
        }
      else
        null;
  };

  lineCount = text: length (lib.splitString "\n" text);
  clean = s: if s ? text then s // { text = lib.removeSuffix "\n" s.text; } else s;

  layout =
    (lib.foldl'
      (
        acc: seg:
        let
          n = seg.lines or (lineCount seg.text);
        in
        {
          next = acc.next + n;
          segs = acc.segs ++ [
            (
              seg
              // {
                start = acc.next;
                end = acc.next + n - 1;
              }
            )
          ];
        }
      )
      {
        next = 1;
        segs = [ ];
      }
      (map clean segments)
    ).segs;

  rendered = map (
    s:
    if s ? render then
      let
        text = s.render layout;
      in
      assert lib.assertMsg (
        lineCount text == s.lines
      ) "${name}: segment `${s.label}` has the wrong line count";
      text
    else
      s.text
  ) layout;

  source = concatStringsSep "\n" rendered + "\n";

  sourceMap = {
    version = 1;
    file = name;
    segments = map (s: {
      inherit (s) start end;
      origin = {
        inherit (s) kind label;
      }
      // lib.optionalAttrs (s ? file) { inherit (s) file; };
    }) layout;
  };

  # -- validation ----------------------------------------------------------
  errors =
    map (a: a.message) (filter (a: !a.assertion) config.assertions)
    ++ optionals argsEnabled argsResult.errors
    ++
      optional (argsEnabled && style == "assoc" && !lib.elem "assoc-arrays" caps)
        "args.vars.style = \"assoc\" needs assoc-arrays, which ${config.lang} target ${targetName} does not have"
    ++ callErrors;

  checked =
    x:
    if errors == [ ] then
      x
    else
      throw "nix-scripter: script `${name}` has errors:\n${
        concatStringsSep "\n" (map (e: "  - ${e}") errors)
      }";

  # -- checks --------------------------------------------------------------
  sourceFile = pkgs.writeTextFile {
    name = "${name}-source";
    text = source;
    executable = true;
  };
  sourceMapFile = pkgs.writeText "${name}-sourcemap.json" (builtins.toJSON sourceMap);
  userSourceFile = pkgs.writeText "${name}-user-source" user.text;

  checkerLib = import ./checkers-driver.nix { inherit lib pkgs; };
  activeCheckers = lib.filterAttrs (
    cname: c:
    config.check.enable && config.check.${cname}.enable && lib.elem config.lang (c.backends or [ ])
  ) registry.checkers;
  checkersAt = stage: lib.filterAttrs (cname: _: config.check.${cname}.stage == stage) activeCheckers;
  checkerRun =
    cname: c:
    checkerLib.run {
      inherit name cname c;
      cfg = config.check.${cname};
      inherit config;
      inherit sourceFile sourceMapFile userSourceFile;
    };

  buildChecks = lib.mapAttrsToList checkerRun (checkersAt "build");
  flakeChecks = lib.mapAttrs' (
    cname: c:
    let
      r = checkerRun cname c;
    in
    lib.nameValuePair cname (
      pkgs.runCommandLocal "${name}-check-${cname}" { nativeBuildInputs = r.packages; } ''
        ${r.script}
        touch $out
      ''
    )
  ) (checkersAt "flake-check");

  argsTests = optionals (argsEnabled && ir.tests != [ ]) [
    (import ./args-tests.nix {
      inherit
        lib
        pkgs
        name
        ir
        argsCode
        backend
        config
        ;
    })
  ];

  checks = flakeChecks // lib.optionalAttrs (argsTests != [ ]) { args = lib.head argsTests; };

  # -- emit ----------------------------------------------------------------
  completionFiles = lib.optionalAttrs argsEnabled {
    "share/bash-completion/completions/${name}" = completions.bash ir;
    "share/zsh/site-functions/_${name}" = completions.zsh ir;
    "share/fish/vendor_completions.d/${name}.fish" = completions.fish ir;
  };

  package =
    pkgs.runCommandLocal name
      (
        {
          nativeBuildInputs = lib.unique (concatMap (r: r.packages) buildChecks);
          passAsFile = map sanitizeAttr (lib.attrNames completionFiles);
          passthru = {
            inherit
              config
              sourceMap
              checks
              extend
              ;
            source = sourceFile;
            sourceMapFile = sourceMapFile;
            argsIR = if argsEnabled then ir else null;
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
        // lib.mapAttrs' (n: v: lib.nameValuePair (sanitizeAttr n) v) completionFiles
        // lib.optionalAttrs standalone { allowedReferences = [ ]; }
      )
      ''
        mkdir -p $out/bin
        cp ${sourceFile} $out/bin/${name}
        chmod 755 $out/bin/${name}
        ${lib.optionalString standalone ''
          if grep -n '/nix/store/' $out/bin/${name} >&2; then
            echo "${name}: standalone script contains /nix/store paths (see lines above)" >&2
            exit 1
          fi
        ''}
        ${concatMapStringsSep' (r: r.script) buildChecks}
        ${concatMapStringsSep' (path: ''
          mkdir -p $out/${dirOf path}
          cp "''$${sanitizeAttr path}Path" $out/${path}
        '') (lib.attrNames completionFiles)}
      '';

  sanitizeAttr = p: "completion_" + lib.replaceStrings [ "/" "." "-" "+" ] [ "_" "_" "_" "_" ] p;
  concatMapStringsSep' = f: xs: concatStringsSep "\n" (map f xs);
in
checked package
