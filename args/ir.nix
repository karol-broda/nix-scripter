# Normalizes an evaluated argument spec into a language-neutral IR and
# validates it. Codegen for every backend works from this IR only.
#
#   ir { name; version; description; spec; } → { ir; errors; }
{ lib }:
let
  inherit (lib)
    concatMap
    concatStringsSep
    filter
    length
    mapAttrsToList
    optional
    optionals
    ;

  irVersion = 1;

  sanitize = lib.replaceStrings [ "-" ] [ "_" ];

  toStr =
    v:
    if v == null then
      null
    else if lib.isString v then
      v
    else if lib.isBool v then
      (if v then "1" else "")
    else if lib.isList v then
      map toStr v
    else
      builtins.toJSON v;

  builtinGlobals = {
    verbose = {
      kind = "flag";
      name = "verbose";
      short = "v";
      long = "verbose";
      count = true;
      description = "Increase verbosity (repeatable)";
      action = "verbose";
    };
    quiet = {
      kind = "flag";
      name = "quiet";
      short = "q";
      long = "quiet";
      description = "Only print warnings and errors";
      action = "quiet";
    };
    yes = {
      kind = "flag";
      name = "yes";
      short = "y";
      long = "yes";
      description = "Answer yes to all confirmations";
      action = "yes";
    };
    dryRun = {
      kind = "flag";
      name = "dry-run";
      long = "dry-run";
      description = "Print what would be done without doing it";
      action = "dryRun";
    };
    color = {
      kind = "option";
      name = "color";
      long = "color";
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

  flagDefaults = {
    short = null;
    env = null;
    var = null;
    hidden = false;
    negatable = false;
    count = false;
    default = null;
    description = "";
    action = null;
  };

  optionDefaults = {
    short = null;
    env = null;
    var = null;
    hidden = false;
    values = null;
    pattern = null;
    default = null;
    complete = null;
    required = false;
    repeated = false;
    metavar = null;
    description = "";
    action = null;
  };

  normalizeFlag =
    negatableDefault: name: f:
    flagDefaults
    // {
      kind = "flag";
      inherit name;
      key = sanitize (if f.var != null then f.var else name);
      inherit (f)
        short
        long
        env
        var
        hidden
        count
        description
        ;
      negatable = if f.negatable == null then negatableDefault else f.negatable;
    };

  # `type = "bool"` options behave exactly like flags.
  normalizeOption =
    negatableDefault: name: o:
    if o.type == "bool" then
      flagDefaults
      // {
        kind = "flag";
        inherit name;
        key = sanitize (if o.var != null then o.var else name);
        inherit (o)
          short
          long
          env
          var
          hidden
          description
          ;
        negatable = if o.negatable == null then negatableDefault else o.negatable;
        default = if o.default == null then null else (o.default == true);
      }
    else
      optionDefaults
      // {
        kind = "option";
        inherit name;
        key = sanitize (if o.var != null then o.var else name);
        inherit (o)
          short
          long
          type
          values
          pattern
          env
          var
          hidden
          required
          repeated
          complete
          description
          ;
        metavar = if o.metavar != null then o.metavar else lib.toUpper (sanitize name);
        default = toStr o.default;
      };

  normalizePositional = p: {
    kind = "positional";
    action = null;
    short = null;
    required = false;
    repeated = false;
    inherit (p)
      name
      type
      values
      pattern
      env
      var
      optional
      variadic
      complete
      description
      hidden
      ;
    key = sanitize (if p.var != null then p.var else p.name);
    default = toStr p.default;
    metavar = p.name;
  };

  mkLevel =
    {
      spec,
      path,
      prog,
      negatableDefault,
      inherited,
      globals,
    }:
    let
      id = concatStringsSep "__" ([ "root" ] ++ map sanitize path);
      ownFlags =
        mapAttrsToList (normalizeFlag negatableDefault) spec.flags
        ++ mapAttrsToList (normalizeOption negatableDefault) (
          lib.filterAttrs (_: o: o.type == "bool") spec.options
        )
        ++ globals.flags;
      ownOptions =
        mapAttrsToList (normalizeOption negatableDefault) (
          lib.filterAttrs (_: o: o.type != "bool") spec.options
        )
        ++ globals.options;
      own = ownFlags ++ ownOptions;
      inheritedHere = if path == [ ] || spec.inheritGlobals then inherited else [ ];
      childInherited = inheritedHere ++ own;
    in
    {
      inherit id path;
      display = concatStringsSep " " ([ prog ] ++ path);
      name = if path == [ ] then prog else lib.last path;
      inherit (spec)
        description
        aliases
        hidden
        groups
        ;
      examples = map (e: removeAttrs e [ "_module" ]) spec.examples;
      flags = ownFlags;
      options = ownOptions;
      positional = map normalizePositional spec.positional;
      inherited = inheritedHere;
      constraints = map (c: {
        inherit (c) exclusive requires oneOf;
      }) spec.constraints;
      body =
        if spec.text != null then
          {
            text = spec.text;
            file = "${concatStringsSep "." ([ "commands" ] ++ path)}.text";
          }
        else if spec.src != null then
          {
            text = builtins.readFile spec.src;
            file = baseNameOf spec.src;
          }
        else
          null;
      commands = mapAttrsToList (
        name: sub:
        mkLevel {
          spec = sub;
          path = path ++ [ name ];
          inherit prog negatableDefault;
          inherited = childInherited;
          globals = {
            flags = [ ];
            options = [ ];
          };
        }
      ) spec.commands;
    };

  # --- validation ---------------------------------------------------------

  levels = level: [ level ] ++ concatMap levels level.commands;

  duplicates = xs: lib.unique (filter (x: length (filter (y: y == x) xs) > 1) xs);

  reservedVars = [
    "PATH"
    "IFS"
    "HOME"
    "PWD"
    "OLDPWD"
    "SHELL"
    "USER"
    "UID"
    "EUID"
    "PPID"
    "RANDOM"
    "LINENO"
    "SECONDS"
    "OPTIND"
    "OPTARG"
    "BASH"
    "BASH_ENV"
    "ENV"
    "CDPATH"
    "PS1"
    "PS2"
    "PS4"
    "TERM"
  ];

  validIdent = s: builtins.match "[A-Za-z_][A-Za-z0-9_]*" s != null;

  validateLevel =
    vars: level:
    let
      where =
        if level.path == [ ] then "args" else "args.commands.${concatStringsSep ".commands." level.path}";
      all = level.inherited ++ level.flags ++ level.options;
      named = all ++ level.positional;
      longs = map (a: a.long) all ++ [ "help" ] ++ optional (level.path == [ ]) "version";
      shorts = filter (s: s != null) (map (a: a.short) all) ++ [ "h" ];
      keys = map (a: a.key) named;
      names = map (a: a.name) named;
      pos = level.positional;
      firstVariadic = lib.findFirst (i: (lib.elemAt pos i).variadic) null (lib.range 0 (length pos - 1));
      firstOptional = lib.findFirst (i: (lib.elemAt pos i).optional) null (lib.range 0 (length pos - 1));
      checkValues =
        a:
        optionals (a.kind != "flag") (
          optional (
            a.type == "enum" && a.values == null
          ) "${where}: `${a.name}` has type enum but no `values`"
          ++ optional (
            a.values != null && a.default != null && lib.any (d: !lib.elem d a.values) (lib.toList a.default)
          ) "${where}: default of `${a.name}` is not one of ${builtins.toJSON a.values}"
          ++ optional (
            a.default != null && lib.isList a.default && !(a.repeated or a.variadic or false)
          ) "${where}: `${a.name}` has a list default but is not repeated/variadic"
        );
      constraintNames = concatMap (
        c:
        (if c.exclusive != null then c.exclusive else [ ])
        ++ (if c.oneOf != null then c.oneOf else [ ])
        ++ (
          if c.requires != null then
            lib.attrNames c.requires ++ lib.concatLists (lib.attrValues c.requires)
          else
            [ ]
        )
      ) level.constraints;
      groupNames = lib.concatLists (lib.attrValues level.groups);
    in
    map (d: "${where}: duplicate long option `--${d}`") (duplicates longs)
    ++ map (d: "${where}: duplicate short option `-${d}`") (duplicates shorts)
    ++ map (d: "${where}: duplicate argument key `${d}`") (duplicates keys)
    ++ optional (
      pos != [ ] && level.commands != [ ]
    ) "${where}: a level cannot have both positional arguments and commands"
    ++ optional (
      firstVariadic != null && firstVariadic != length pos - 1
    ) "${where}: only the last positional argument can be variadic"
    ++ optional (
      firstOptional != null && lib.any (p: !p.optional && !p.variadic) (lib.drop firstOptional pos)
    ) "${where}: required positional arguments cannot follow optional ones"
    ++ concatMap checkValues named
    ++ map (n: "${where}: constraint refers to unknown argument `${n}`") (
      filter (n: !lib.elem n names) (lib.unique constraintNames)
    )
    ++ map (n: "${where}: group refers to unknown argument `${n}`") (
      filter (n: !lib.elem n names) (lib.unique groupNames)
    )
    ++ concatMap (
      a:
      let
        v = varName vars a;
      in
      optional (!validIdent a.key) "${where}: `${a.name}` gives invalid key `${a.key}`"
      ++ optional (
        vars.style == "globals" && lib.elem v reservedVars
      ) "${where}: `${a.name}` would overwrite the shell variable `${v}`; set `var`"
    ) named;

  varName =
    vars: a:
    let
      cased =
        if vars.case == "upper" then
          lib.toUpper a.key
        else if vars.case == "lower" then
          lib.toLower a.key
        else
          a.key;
    in
    if a.var != null then a.var else vars.prefix + cased;

  ir =
    {
      name,
      version,
      description,
      spec,
      style,
    }:
    let
      g = spec.globals;
      globalArgs = lib.attrValues (
        lib.filterAttrs (n: _: g.${n} or false) (
          lib.mapAttrs (
            _: a:
            (if a.kind == "flag" then flagDefaults else optionDefaults)
            // a
            // {
              key = sanitize a.name;
            }
          ) builtinGlobals
        )
      );
      root = mkLevel {
        inherit spec;
        path = [ ];
        prog = name;
        negatableDefault = spec.defaults.negatable;
        inherited = [ ];
        globals = {
          flags = filter (a: a.kind == "flag") globalArgs;
          options = filter (a: a.kind == "option") globalArgs;
        };
      };
      vars = spec.vars // {
        inherit style;
      };
      allLevels = levels root;
      # keys must be unique along every root → leaf path (siblings may share)
      pathErrors = concatMap (
        level:
        map (d: "args: key `${d}` is used by `${level.display}` and one of its parent commands") (
          duplicates (map (a: a.key) (level.inherited ++ level.flags ++ level.options ++ level.positional))
        )
      ) allLevels;
      treeErrors = lib.unique (concatMap (validateLevel vars) allLevels ++ pathErrors);
      allKeys = lib.unique (
        concatMap (l: map (a: a.key) (l.flags ++ l.options ++ l.positional)) allLevels
      );
      # distinct keys must not map to the same generated variable
      keyVars = lib.unique (
        concatMap (
          l:
          map (a: {
            inherit (a) key;
            var = varName vars a;
          }) (l.flags ++ l.options ++ l.positional)
        ) allLevels
      );
      varErrors =
        optionals (style == "globals") (
          map (d: "args: generated variable `${d}` is used by several arguments; set `var`") (
            duplicates (map (kv: kv.var) keyVars)
          )
        )
        ++ optional (!validIdent vars.name) "args.vars.name `${vars.name}` is not a valid identifier";
    in
    {
      ir = {
        inherit irVersion;
        inherit
          name
          version
          description
          root
          vars
          ;
        globals = {
          inherit (g) help version;
        };
        keys = allKeys;
        levels = allLevels;
        hasCommands = root.commands != [ ];
        tests = map (t: removeAttrs t [ "_module" ]) spec.tests;
      };
      errors = treeErrors ++ varErrors;
    };
in
{
  inherit
    ir
    irVersion
    sanitize
    varName
    ;
}
