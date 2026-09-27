{
  lib,
  registry,
  config,
  context,
  cli,
}:
let
  inherit (lib) concatMap concatStringsSep;
  inherit (context) backend target caps;

  namespaces = lib.listToAttrs (
    lib.mapAttrsToList (fname: f: lib.nameValuePair (f.namespace or fname) fname) registry.features
  );

  sources = [ context.user.text ] ++ lib.optionals cli.enable (map (b: b.text) cli.code.bodies);

  versionOf = t: concatStringsSep "." (map toString t.version);
  targetsOldestFirst = lib.sort (a: b: lib.versionOlder (versionOf a.value) (versionOf b.value)) (
    lib.mapAttrsToList lib.nameValuePair backend.targets
  );

  resolve =
    call:
    let
      featureName = namespaces.${call.ns};
      functions = registry.features.${featureName}.functions or { };
    in
    {
      inherit featureName functions;
      full = backend.naming call.ns call.fn;
      spec = functions.${call.fn} or null;
      enabled = config.features.${featureName}.enable;
      prefix = call.ns;
    };

  disabledFeatureError = r: "`${r.full}` is used, but features.${r.featureName} is not enabled";

  unknownFunctionError =
    r:
    let
      candidates = map (backend.naming r.prefix) (lib.attrNames r.functions);
      closest = lib.findFirst (lib.strings.levenshteinAtMost 2 r.full) null candidates;
    in
    "`${r.full}` is not a function of the ${r.featureName} feature"
    + lib.optionalString (closest != null) " (did you mean `${closest}`?)";

  missingCapabilityError =
    r: missing:
    let
      needs = r.spec.needs or [ ];
      lowest = lib.findFirst (t: lib.all (c: lib.elem c t.value.caps) needs) null targetsOldestFirst;
    in
    "`${r.full}` needs ${concatStringsSep ", " missing}, which ${config.lang} target ${target} does not have"
    + lib.optionalString (lowest != null) " (lowest target with it: ${lowest.name})";

  errorsOf =
    r:
    let
      missing = lib.filter (c: !lib.elem c caps) (r.spec.needs or [ ]);
    in
    if !r.enabled then
      [ (disabledFeatureError r) ]
    else if r.spec == null then
      [ (unknownFunctionError r) ]
    else if missing != [ ] then
      [ (missingCapabilityError r missing) ]
    else
      [ ];

  libraryCalls = map resolve (
    lib.filter (c: namespaces ? ${c.ns}) (lib.unique (concatMap backend.scan sources))
  );

  bareFunctionsOf =
    featureName:
    lib.attrNames (
      lib.filterAttrs (_: s: s.bare or false) (registry.features.${featureName}.functions or { })
    );

  bareCalls = concatMap (
    featureName:
    map (fn: registry.features.${featureName}.functions.${fn}) (
      lib.unique (concatMap (backend.scanBare (bareFunctionsOf featureName)) sources)
    )
  ) context.features;
in
{
  errors = concatMap errorsOf libraryCalls;
  usedFunctions = lib.filter (s: s != null) (map (r: r.spec) libraryCalls) ++ bareCalls;
}
