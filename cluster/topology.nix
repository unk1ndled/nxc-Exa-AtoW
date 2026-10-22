# The shared cluster: ebuffer, ebservice, a SLURM frontend and controller,
# and the compute nodes a composition declares. A composition is a module
# that sets the options below; `frontend` and each group's `node` are NixOS
# configuration that enables apps from ../apps.
composition:
{ pkgs, ... }:
let
  inherit (pkgs) lib;
  inherit (lib) mkOption types;

  cluster =
    (lib.evalModules {
      modules = [
        {
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
        }
        composition
      ];
    }).config;

  computeNodes = lib.concatMapAttrs (
    group:
    { count, node }:
    lib.listToAttrs (
      builtins.map (index: lib.nameValuePair "${group}${toString index}" node) (lib.range 1 count)
    )
  ) cluster.computeGroups;
  invalidGroupNames = builtins.filter (
    name: builtins.match "[a-z]+(-[a-z]+)*" name == null
  ) (builtins.attrNames cluster.computeGroups);

  computeNodeNames = builtins.attrNames computeNodes;
  slurmComputeNodes = builtins.concatStringsSep "," computeNodeNames;
  slurmNodeNames = builtins.map (
    nodeName:
    let
      # Each node advertises the apps it enables as SLURM features.
      apps = computeNodes.${nodeName}.exa-atow.apps or { };
      features = builtins.filter (app: apps.${app}.enable or false) (builtins.attrNames apps);
      featureConfig =
        if features == [ ] then "" else " Feature=${builtins.concatStringsSep "," features}";
    in
    "${nodeName} CPUs=1 RealMemory=900 State=UNKNOWN${featureConfig}"
  ) computeNodeNames;

  clusterBase =
    { ... }:
    {
      services.slurm = {
        controlMachine = "controller";
        nodeName = slurmNodeNames;
        partitionName = [
          "main Nodes=${slurmComputeNodes} Default=YES MaxTime=INFINITE State=UP"
        ];
        extraConfig = ''
          MpiDefault=pmix
        '';
      };

      systemd.tmpfiles.rules = [
        # Munge rejects undersized keys; this is bootstrap-only and matches the
        # deterministic key pattern used by the upstream NixOS SLURM test.
        "f /etc/munge/munge.key 0400 munge munge - mungeverryweakkeybuteasytointegratoinatest"
      ];

      networking.firewall.enable = false;
      nxc.users = {
        names = [ "user1" ];
        prefixHome = "/users";
      };
    };
  computeRoles = builtins.mapAttrs (
    _nodeName: node:
    { ... }:
    {
      imports = [
        clusterBase
        ../apps
        node
      ];
      services.slurm.client.enable = true;
      nxc.sharedDirs."/users".server = "controller";
    }
  ) computeNodes;

  waitFor = machine: unit: ''
    ${machine}.succeed(
      "timeout 180 sh -c 'until systemctl is-active --quiet ${unit}; do sleep 1; done'"
    )
  '';
  waitForCluster =
    "serial_stdout_off()\n"
    + waitFor "ebuffer" "ebuffer.service"
    + waitFor "ebservice" "ebservice.service && eb-login >/dev/null 2>&1"
    + waitFor "controller" "slurmctld.service"
    + builtins.concatStringsSep "" (builtins.map (node: waitFor node "slurmd.service") computeNodeNames);
in
if computeNodeNames == [ ] then
  builtins.throw "a composition must declare at least one compute node"
else if invalidGroupNames != [ ] then
  builtins.throw (
    "compute group names must be lowercase words joined by '-', without digits; invalid names: "
    + builtins.concatStringsSep ", " invalidGroupNames
  )
else
  {
    roles = {
      ebuffer =
        { lib, ... }:
        {
          networking.firewall.enable = false;
          services.ebuffer = {
            enable = true;
            configDir = ./ebuffer;
            host = "0.0.0.0";
          };
          systemd.services.ebuffer.preStart = lib.mkForce ''
            echo "Copying ebuffer config without NFS ownership metadata"
            cp -r --no-preserve=ownership ${./ebuffer}/* .
            chmod -R u+w .
            mkdir -p ./data
            touch ./data/eb_database.db
          '';
          environment.systemPackages = [
            pkgs.ebuffer
            pkgs.ebhelpers
          ];
        };

      ebservice =
        { lib, ... }:
        {
          networking.firewall.enable = false;
          services.ebservice = {
            enable = true;
            ebserverhost = "ebuffer";
            configDir = ./ebservice;
            host = "0.0.0.0";
          };
          systemd.services.ebservice.preStart = lib.mkForce ''
            echo "Copying ebservice config without NFS ownership metadata"
            cp -r --no-preserve=ownership ${./ebservice}/* .
            chmod -R u+w .
            mkdir -p ./data
            touch ./data/eb_database.db
          '';
          environment.systemPackages = [
            pkgs.ebservice
            pkgs.ebhelpers
          ];
        };

      frontend =
        { ... }:
        {
          imports = [
            clusterBase
            ../apps
            cluster.frontend
          ];
          services.slurm.enableStools = true;
          nxc.sharedDirs."/users".server = "controller";
        };

      controller =
        { ... }:
        {
          imports = [ clusterBase ];
          services.slurm.server.enable = true;
          nxc.sharedDirs."/users".export = true;
        };
    }
    // computeRoles;

    testScript = waitForCluster + cluster.testScript;
  }
