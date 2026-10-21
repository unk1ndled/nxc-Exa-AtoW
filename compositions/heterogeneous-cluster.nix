# Different software per compute node, advertised to SLURM as node features.
# OpenQCD runs on both nodes; MPI Hello is installed only on compute1.
{ apps, ... }:
let
  inherit (apps) mpi-hello openqcd;
in
{
  frontendModules = [
    mpi-hello.module
    openqcd.module
  ];
  computeNodes = {
    compute1 = {
      modules = [
        mpi-hello.module
        openqcd.module
      ];
      features = [
        "mpi-hello"
        "openqcd"
      ];
    };
    compute2 = {
      modules = [ openqcd.module ];
      features = [ "openqcd" ];
    };
  };

  testModules = [ openqcd.test.frontendModule ];
  testScript = openqcd.test.testScript + ''
    compute1.succeed(
      "command -v mpi-hello >/dev/null; command -v ym1 >/dev/null"
    )
    compute2.succeed(
      "! command -v mpi-hello >/dev/null; command -v ym1 >/dev/null"
    )
    controller.succeed(
      "scontrol show node compute1 --oneliner "
      "| grep -Eq 'AvailableFeatures=[^ ]*mpi-hello'; "
      "scontrol show node compute2 --oneliner "
      "| grep -Eq 'AvailableFeatures=openqcd([[:space:]]|$)'"
    )
  '';
}
