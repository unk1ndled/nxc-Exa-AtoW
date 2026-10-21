# The shared cluster: ebuffer, ebservice, a SLURM frontend and controller,
# and the compute nodes a composition declares. `frontend` and each compute
# node are NixOS configuration that enables apps from ./apps.
{
  frontend,
  computeNodes,
  testScript,
}:
{ pkgs, ... }:
let
  computeNodeNames = builtins.attrNames computeNodes;
  invalidComputeNodeNames = builtins.filter (
    name: builtins.match "compute[1-9][0-9]*" name == null
  ) computeNodeNames;
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
        ./apps
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
else if invalidComputeNodeNames != [ ] then
  builtins.throw (
    "compute node names must match compute[1-9][0-9]*; invalid names: "
    + builtins.concatStringsSep ", " invalidComputeNodeNames
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
            configDir = ./config/ebuffer;
            host = "0.0.0.0";
          };
          systemd.services.ebuffer.preStart = lib.mkForce ''
            echo "Copying ebuffer config without NFS ownership metadata"
            cp -r --no-preserve=ownership ${./config/ebuffer}/* .
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
            configDir = ./config/ebservice;
            host = "0.0.0.0";
          };
          systemd.services.ebservice.preStart = lib.mkForce ''
            echo "Copying ebservice config without NFS ownership metadata"
            cp -r --no-preserve=ownership ${./config/ebservice}/* .
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
            ./apps
            frontend
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

    testScript = waitForCluster + testScript;
  }
