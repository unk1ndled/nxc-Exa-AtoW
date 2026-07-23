let
  common = import ./common.nix;
  # NXC's VM runner unconditionally executes `sync` after the embedded test.
  # Refresh its single-use SSH subprocesses so that final command has a fresh
  # channel rather than reusing the one consumed by each role's test command.
  finalize = ''
    for machine in machines:
        machine.ctx.flavour.start_process_shell(machine)
    # More than four nodes sets this flag, but NXC's local VM path does not
    # create an HTTP daemon and would otherwise call stop() on None.
    driver.ctx.use_httpd = False
  '';
  withCommon =
    applicationTest:
    applicationTest
    // {
      testScript = common + applicationTest.testScript + finalize;
    };
in
{
  mpi-hello = withCommon (import ./mpi-hello.nix { });
  openqcd = withCommon (import ./openqcd.nix { });
  multi-software-composition = withCommon (import ./multi-software-composition.nix);
}
