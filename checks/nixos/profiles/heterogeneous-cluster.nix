let
  openqcd = import ./openqcd.nix { assertIsolated = false; };
in
{
  inherit (openqcd) frontendModule;

  # OpenQCD is present on both nodes and can still run its two-node job. MPI
  # Hello is deliberately installed only on compute1.
  testScript = openqcd.testScript + ''
    for machine in [compute1, compute2, controller]:
        machine.ctx.flavour.start_process_shell(machine)
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
