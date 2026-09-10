# Turns a directory of scripts into script modules:
#
#   deploy.sh          → script "deploy" (lang from extension)
#   deploy.nix         → optional sidecar module merged into "deploy"
#   release.nix        → a module on its own (must set text/src)
#   backup/default.nix → directory script; `main.<ext>` is used as src if present
#   _lib.sh            → ignored (leading underscore)
{ lib, registry }:
{
  dir,
  shLang ? "bash",
  prefix ? "",
}:
let
  entries = lib.filterAttrs (n: _: !lib.hasPrefix "_" n && !lib.hasPrefix "." n) (
    builtins.readDir dir
  );

  langOf =
    ext:
    if ext == "sh" && registry.backends ? ${shLang} then
      shLang
    else
      lib.findFirst (b: lib.elem ext (registry.backends.${b}.extensions or [ ])) null (
        lib.attrNames registry.backends
      );

  splitExt =
    file:
    let
      m = builtins.match "(.+)\\.([^.]+)" file;
    in
    if m == null then
      null
    else
      {
        base = lib.elemAt m 0;
        ext = lib.elemAt m 1;
      };

  files = lib.filterAttrs (_: t: t == "regular" || t == "symlink") entries;
  dirs = lib.filterAttrs (_: t: t == "directory") entries;

  scriptFiles = lib.filterAttrs (_: v: v != null) (
    lib.mapAttrs' (
      file: _:
      let
        s = splitExt file;
        lang = if s == null then null else langOf s.ext;
      in
      lib.nameValuePair (if s == null then file else s.base) (
        if s == null || lang == null then
          null
        else
          {
            inherit lang;
            src = dir + "/${file}";
          }
      )
    ) files
  );

  nixFiles = lib.mapAttrs' (
    file: _: lib.nameValuePair (lib.removeSuffix ".nix" file) (dir + "/${file}")
  ) (lib.filterAttrs (file: _: lib.hasSuffix ".nix" file) files);

  fromFiles = lib.mapAttrs (name: _: {
    imports =
      lib.optional (scriptFiles ? ${name}) {
        inherit (scriptFiles.${name}) lang src;
      }
      ++ lib.optional (nixFiles ? ${name}) nixFiles.${name};
    name = lib.mkDefault (prefix + name);
  }) (scriptFiles // nixFiles);

  fromDirs = lib.mapAttrs (
    name: _:
    let
      sub = dir + "/${name}";
      subEntries = builtins.readDir sub;
      mains = lib.filter (f: lib.hasPrefix "main." f && langOf (lib.removePrefix "main." f) != null) (
        lib.attrNames subEntries
      );
      main = lib.head mains;
    in
    {
      imports =
        lib.optional (subEntries ? "default.nix") (sub + "/default.nix")
        ++ lib.optional (mains != [ ]) {
          lang = langOf (lib.removePrefix "main." main);
          src = sub + "/${main}";
        };
      name = lib.mkDefault (prefix + name);
    }
  ) (lib.filterAttrs (name: _: builtins.pathExists (dir + "/${name}/default.nix")) dirs);
in
lib.mapAttrs' (name: m: lib.nameValuePair (prefix + name) m) (fromFiles // fromDirs)
