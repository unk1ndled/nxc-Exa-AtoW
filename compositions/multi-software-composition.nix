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
  testScript = mpi-hello.test.testScript + openqcd.test.testScript;
}
