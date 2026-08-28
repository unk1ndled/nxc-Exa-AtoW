let
  mpiHello = import ./mpi-hello.nix { assertIsolated = false; };
  openqcd = import ./openqcd.nix { assertIsolated = false; };
in
{
  frontendModule =
    { ... }:
    {
      imports = [
        mpiHello.frontendModule
        openqcd.frontendModule
      ];
    };

  # Exercise both packages through SLURM. Their jobs also prove that both
  # executables are available on the compute nodes, not only the frontend.
  # The pinned VM driver consumes one SSH subprocess per machine command, so
  # refresh the frontend channel before issuing the second application's test.
  testScript =
    mpiHello.testScript
    + ''
      frontend.ctx.flavour.start_process_shell(frontend)
    ''
    + openqcd.testScript;
}
