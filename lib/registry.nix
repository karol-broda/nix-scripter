# Unlike `lib.makeExtensible`, categories are merged one level deep, so an
# extension `final: prev: { features.git = …; }` keeps every other feature.
{ lib }:
let
  categories = [
    "backends"
    "features"
    "checkers"
    "presets"
  ];

  mergeLayer =
    prev: layer:
    prev
    // lib.mapAttrs (
      name: value: if lib.elem name categories then (prev.${name} or { }) // value else value
    ) layer;

  mkRegistry =
    layers:
    let
      self = lib.foldl' (prev: ext: mergeLayer prev (ext self prev)) { } layers;
    in
    self
    // {
      extend = ext: mkRegistry (layers ++ [ ext ]);
    };

  base = _final: _prev: {
    backends = {
      bash = import ../backends/bash { inherit lib; };
    };

    features = {
      core = import ../features/core { inherit lib; };
      ctx = import ../features/ctx { inherit lib; };
      ui = import ../features/ui { inherit lib; };
    };

    checkers = import ./checkers { inherit lib; };

    presets = import ../presets { inherit lib; };
  };
in
mkRegistry [ base ]
