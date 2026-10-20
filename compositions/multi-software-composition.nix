# Both apps on every node; both two-node jobs must pass.
{ apps, uniform }:
let
  inherit (apps) mpi-hello openqcd;
in
uniform [
  mpi-hello.module
  openqcd.module
]
// {
  testModules = [
    mpi-hello.test.frontendModule
    openqcd.test.frontendModule
  ];
  # The pinned NXC VM driver accepts one command per machine SSH subprocess,
  # so the frontend channel is restarted before the second app's test.
  testScript =
    mpi-hello.test.testScript
    + ''
      frontend.ctx.flavour.start_process_shell(frontend)
    ''
    + openqcd.test.testScript;
}
