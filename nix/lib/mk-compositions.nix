let
  profiles = import ../profiles;

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

  normalizeProfile =
    name: profile:
    if !builtins.isAttrs profile then
      builtins.throw "${name} profile must be an attribute set"
    else if !(profile ? check) then
      builtins.throw "${name} profile must declare its check"
    else if profile ? computeNodes then
      {
        frontendModules = asModuleList (profile.frontendModules or [ ]);
        computeNodes = normalizeComputeNodes name profile.computeNodes;
      }
    else if profile ? modules then
      let
        modules = asModuleList profile.modules;
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
      }
    else
      builtins.throw "${name} profile must declare modules or computeNodes";

  mkComposition =
    name: profile:
    let
      selection = normalizeProfile name profile;
      computeNodeNames = builtins.attrNames selection.computeNodes;
      check = (import ../../checks/nixos/with-readiness.nix { inherit computeNodeNames; }) profile.check;
    in
    import ./mk-topology.nix {
      frontendModules = selection.frontendModules ++ [ check.frontendModule ];
      inherit (selection) computeNodes;
      testScript = check.testScript;
    };
in
builtins.mapAttrs mkComposition profiles
