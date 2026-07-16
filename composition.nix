{
  frontendModules ? [ ],
  computeModules ? [ ],
  testScript ? "",
}:
{ pkgs, ... }:
let
  computeNodes = 2;
  computeNodesString = toString computeNodes;

  clusterBase =
    { ... }:
    {
      services.slurm = {
        controlMachine = "controller";
        nodeName = [ "compute[1-${computeNodesString}] CPUs=1 RealMemory=900 State=UNKNOWN" ];
        partitionName = [
          "main Nodes=compute[1-${computeNodesString}] Default=YES MaxTime=INFINITE State=UP"
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
in
{
  roles = {
    ebuffer =
      { ... }:
      {
        networking.firewall.enable = false;
        services.ebuffer = {
          enable = true;
          configDir = ./config/ebuffer;
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
        networking.firewall.enable = false;
        services.ebservice = {
          enable = true;
          ebserverhost = "ebuffer";
          configDir = ./config/ebservice;
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

    compute =
      { ... }:
      {
        imports = [ clusterBase ] ++ computeModules;
        services.slurm.client.enable = true;
        nxc.sharedDirs."/users".server = "controller";
      };
  };

  rolesDistribution.compute = computeNodes;
  inherit testScript;
}
