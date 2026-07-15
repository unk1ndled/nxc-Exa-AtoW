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
        imports = [
          clusterBase
          ./software
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

    compute =
      { ... }:
      {
        imports = [
          clusterBase
          ./software
        ];
        services.slurm.client.enable = true;
        nxc.sharedDirs."/users".server = "controller";
      };
  };

  rolesDistribution.compute = computeNodes;

  testScript = ''
    ebuffer.wait_for_unit("ebuffer.service")
    ebservice.wait_for_unit("ebservice.service")
    ebservice.succeed("eb-login")
    controller.wait_for_unit("slurmctld.service")
    compute1.wait_for_unit("slurmd.service")
    compute2.wait_for_unit("slurmd.service")
    frontend.succeed(
      "su - user1 -c 'cd /users/user1 && "
      "sbatch --wait --nodes=2 --ntasks=2 --ntasks-per-node=1 "
      "--output=mpi-hello.out --wrap=\"srun --mpi=pmix mpi-hello\"'"
    )
    frontend.succeed("test $(grep -c 'Hello from rank' /users/user1/mpi-hello.out) -eq 2")
    frontend.succeed("grep -q 'rank 0 of 2' /users/user1/mpi-hello.out")
    frontend.succeed("grep -q 'rank 1 of 2' /users/user1/mpi-hello.out")
  '';
}
