# Every directory in apps/ becomes a composition that installs that app on the
# frontend and on two compute nodes. Each file in compositions/ adds a
# composition that combines several apps or lays them out per node.
let
  topology = import ./topology.nix;

  directoryNames =
    path:
    let
      entries = builtins.readDir path;
    in
    builtins.filter (name: entries.${name} == "directory") (builtins.attrNames entries);

  # An app directory holds a NixOS module (default.nix) and its NXC test (test.nix).
  apps = builtins.listToAttrs (
    builtins.map (name: {
      inherit name;
      value = {
        module = ./apps + "/${name}";
        test = import (./apps + "/${name}/test.nix");
      };
    }) (directoryNames ./apps)
  );

  # The same modules on the frontend and on two identical compute nodes.
  uniform = modules: {
    frontendModules = modules;
    computeNodes = {
      compute1.modules = modules;
      compute2.modules = modules;
    };
  };

  appCompositions = builtins.mapAttrs (
    _name: app:
    topology (
      uniform [ app.module ]
      // {
        testModules = [ app.test.frontendModule ];
        inherit (app.test) testScript;
      }
    )
  ) apps;

  combinedCompositions = builtins.listToAttrs (
    builtins.map (file: {
      name = builtins.replaceStrings [ ".nix" ] [ "" ] file;
      value = topology (import (./compositions + "/${file}") { inherit apps uniform; });
    }) (builtins.attrNames (builtins.readDir ./compositions))
  );
in
appCompositions // combinedCompositions
