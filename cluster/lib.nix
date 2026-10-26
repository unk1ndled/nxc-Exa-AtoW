# Helpers for cluster/topology.nix: the options a composition sets, how compute
# groups become nodes, the SLURM line of each node, and the readiness checks.
# Nothing here declares a role; the roles stay in topology.nix.
lib:
let
  inherit (lib) mkOption types;
in
rec {
  # The options a composition (an entry of ../compositions.nix) sets.
  compositionOptions = {
    options = {
      frontend = mkOption {
        type = types.attrs;
        default = { };
        description = "NixOS configuration of the SLURM frontend.";
      };
      computeGroups = mkOption {
        description = ''
          Groups of identical compute nodes. A group `compute` with
          `count = 2` becomes the nodes compute1 and compute2.
        '';
        type = types.attrsOf (
          types.submodule {
            options = {
              count = mkOption {
                type = types.ints.positive;
                description = "Number of nodes in the group.";
              };
              node = mkOption {
                type = types.attrs;
                default = { };
                description = "NixOS configuration of every node in the group.";
              };
            };
          }
        );
      };
      testScript = mkOption {
        type = types.lines;
        default = "";
        description = "NXC test run after the cluster readiness checks.";
      };
    };
  };

  # The settings of a composition, with defaults filled in.
  evalComposition =
    composition:
    (lib.evalModules {
      modules = [
        compositionOptions
        composition
      ];
    }).config;

  # Expand each group into its nodes: `compute = { count = 2; node = n; }`
  # becomes `{ compute1 = n; compute2 = n; }`. Group names must not contain
  # digits, so that a node name always maps back to a single group.
  computeNodes =
    computeGroups:
    let
      invalidGroupNames = builtins.filter (name: builtins.match "[a-z]+(-[a-z]+)*" name == null) (
        builtins.attrNames computeGroups
      );
      nodes = lib.concatMapAttrs (
        group:
        { count, node }:
        lib.listToAttrs (
          builtins.map (index: lib.nameValuePair "${group}${toString index}" node) (lib.range 1 count)
        )
      ) computeGroups;
    in
    if invalidGroupNames != [ ] then
      builtins.throw (
        "compute group names must be lowercase words joined by '-', without digits; invalid names: "
        + builtins.concatStringsSep ", " invalidGroupNames
      )
    else if nodes == { } then
      builtins.throw "a composition must declare at least one compute node"
    else
      nodes;

  # The SLURM NodeName line of a node. Each node advertises the packages it
  # enables as SLURM features.
  slurmNodeLine =
    nodeName: node:
    let
      packages = node.exa-atow.pkgs or { };
      features = builtins.filter (name: packages.${name}.enable or false) (
        builtins.attrNames packages
      );
      featureConfig =
        if features == [ ] then "" else " Feature=${builtins.concatStringsSep "," features}";
    in
    "${nodeName} CPUs=1 RealMemory=900 State=UNKNOWN${featureConfig}";

  # NXC test lines waiting up to 180 seconds for a unit to become active.
  waitFor = machine: unit: ''
    ${machine}.succeed(
      "timeout 180 sh -c 'until systemctl is-active --quiet ${unit}; do sleep 1; done'"
    )
  '';

  # The readiness checks run before every composition's test.
  waitForCluster =
    computeNodeNames:
    "serial_stdout_off()\n"
    + waitFor "ebuffer" "ebuffer.service"
    + waitFor "ebservice" "ebservice.service && eb-login >/dev/null 2>&1"
    + waitFor "controller" "slurmctld.service"
    + builtins.concatStringsSep "" (builtins.map (node: waitFor node "slurmd.service") computeNodeNames);
}
