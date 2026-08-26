{
  frontendModules ? [ ],
  computeNodes ? {
    compute1 = {
      modules = [ ];
      features = [ ];
    };
    compute2 = {
      modules = [ ];
      features = [ ];
    };
  },
  testScript ? "",
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
      features = computeNodes.${nodeName}.features;
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
      imports = [ clusterBase ] ++ node.modules;
      services.slurm.client.enable = true;
      nxc.sharedDirs."/users".server = "controller";
    }
  ) computeNodes;
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
          imports = [ clusterBase ] ++ frontendModules;
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

    inherit testScript;
  }
