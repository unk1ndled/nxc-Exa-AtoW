let
  software = import ./software;
  tests = import ./e2e/nxc;
  softwareNames = builtins.attrNames software;
  testNames = builtins.attrNames tests;

  mkComposition =
    name: softwareModule:
    let
      test = tests.${name};
    in
    import ./composition.nix {
      frontendModules = [
        softwareModule
        test.frontendModule
      ];
      computeModules = [ softwareModule ];
      inherit (test) testScript;
    };
in
if softwareNames != testNames then
  builtins.throw (
    "software and E2E plug-ins must have matching names; software: "
    + builtins.concatStringsSep ", " softwareNames
    + "; E2E: "
    + builtins.concatStringsSep ", " testNames
  )
else
  builtins.mapAttrs mkComposition software
