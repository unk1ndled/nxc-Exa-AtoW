# The shared cluster: ebuffer, ebservice, a SLURM frontend and controller,
# and the compute nodes a composition declares. A composition is a module
# that sets the options below; `frontend` and each group's `node` are NixOS
# configuration that enables packages from ../pkgs. The options and the
# helpers below (node expansion, SLURM lines, readiness checks) are in lib.nix.
composition:
{ pkgs, ... }:
let
  inherit (pkgs) lib;
  clusterLib = import ./lib.nix lib;

  cluster = clusterLib.evalComposition composition;
  computeNodes = clusterLib.computeNodes cluster.computeGroups;
  computeNodeNames = builtins.attrNames computeNodes;

  clusterBase =
    { ... }:
    {
      services.slurm = {
        controlMachine = "controller";
        nodeName = lib.mapAttrsToList clusterLib.slurmNodeLine computeNodes;
        partitionName = [
          "main Nodes=${builtins.concatStringsSep "," computeNodeNames} Default=YES MaxTime=INFINITE State=UP"
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
        ../pkgs/modules.nix
        node
      ];
      services.slurm.client.enable = true;
      nxc.sharedDirs."/users".server = "controller";
    }
  ) computeNodes;
in
{
  # concrete nxc composition declaration
  roles = {
    ebuffer =
      { ... }:
      {
        imports = [ ../pkgs/ebuffer ];
        networking.firewall.enable = false;
        services.ebuffer = {
          enable = true;
          configDir = ./ebuffer;
          host = "0.0.0.0";
        };
        environment.systemPackages = [
          pkgs.ebuffer
          pkgs.ebhelpers
        ];
      };

    ebservice =
      { ... }:
      {
        imports = [ ../pkgs/ebservice ];
        networking.firewall.enable = false;
        services.ebservice = {
          enable = true;
          ebserverhost = "ebuffer";
          configDir = ./ebservice;
          host = "0.0.0.0";
        };
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
          ../pkgs/modules.nix
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

  testScript = clusterLib.waitForCluster computeNodeNames + cluster.testScript;
}
