let
  software = import ./software;
  tests = import ./e2e/nxc;
  softwareNames = builtins.attrNames software;
  testNames = builtins.attrNames tests;

  asModuleList = modules: if builtins.isList modules then modules else [ modules ];

  normalizeFeatures =
    name: features:
    if !builtins.isList features || !builtins.all builtins.isString features then
      builtins.throw "${name}.features must be a list of strings"
    else if builtins.any (feature: builtins.match "[A-Za-z0-9_.-]+" feature == null) features then
      builtins.throw "${name}.features may contain only letters, digits, dots, underscores, and hyphens"
    else
      features;

  normalizeComputeNodes =
    compositionName: computeNodes:
    if !builtins.isAttrs computeNodes then
      builtins.throw "${compositionName}.computeNodes must be an attribute set"
    else if builtins.attrNames computeNodes == [ ] then
      builtins.throw "${compositionName}.computeNodes must not be empty"
    else
      builtins.mapAttrs (
        nodeName: node:
        if !builtins.isAttrs node then
          builtins.throw "${compositionName}.computeNodes.${nodeName} must be an attribute set"
        else if !(node ? modules) then
          builtins.throw "${compositionName}.computeNodes.${nodeName}.modules is required"
        else
          {
            modules = asModuleList node.modules;
            features = normalizeFeatures "${compositionName}.computeNodes.${nodeName}" (node.features or [ ]);
          }
      ) computeNodes;

  normalizeSoftware =
    name: softwareDefinition:
    if builtins.isAttrs softwareDefinition && softwareDefinition ? computeNodes then
      {
        frontendModules = asModuleList (softwareDefinition.frontendModules or [ ]);
        computeNodes = normalizeComputeNodes name softwareDefinition.computeNodes;
      }
    else
      let
        modules = asModuleList softwareDefinition;
        node = {
          inherit modules;
          features = [ ];
        };
      in
      {
        frontendModules = modules;
        computeNodes = {
          compute1 = node;
          compute2 = node;
        };
      };

  mkComposition =
    name: softwareDefinition:
    let
      selection = normalizeSoftware name softwareDefinition;
      computeNodeNames = builtins.attrNames selection.computeNodes;
      test = (import ./e2e/nxc/common.nix { inherit computeNodeNames; }) tests.${name};
    in
    import ./composition.nix {
      frontendModules = selection.frontendModules ++ [ test.frontendModule ];
      inherit (selection) computeNodes;
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
