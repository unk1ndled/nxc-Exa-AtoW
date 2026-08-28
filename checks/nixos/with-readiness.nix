# Wrap a profile check with platform and scheduler readiness checks.
{ computeNodeNames }:
applicationTest:
let
  computeReadiness = builtins.concatStringsSep "\n" (
    builtins.map (nodeName: ''
      ${nodeName}.succeed(
        "timeout 180 sh -c 'until systemctl is-active --quiet slurmd.service; do sleep 1; done'"
      )
    '') computeNodeNames
  );
in
applicationTest
// {
  testScript = ''
    serial_stdout_off()
    ebuffer.succeed(
      "timeout 180 sh -c 'until systemctl is-active --quiet ebuffer.service; do sleep 1; done'"
    )
    ebservice.succeed(
      "timeout 180 sh -c 'until systemctl is-active --quiet ebservice.service "
      "&& eb-login >/dev/null 2>&1; do sleep 1; done'"
    )
    controller.succeed(
      "timeout 180 sh -c 'until systemctl is-active --quiet slurmctld.service; do sleep 1; done'"
    )
    ${computeReadiness}
  ''
  + applicationTest.testScript
  + ''
    if driver.ctx.flavour.name == "vm":
        for machine in machines:
            machine.ctx.flavour.start_process_shell(machine)
        # More than four nodes sets this flag, but NXC's local VM path does not
        # create an HTTP daemon and would otherwise call stop() on None.
        driver.ctx.use_httpd = False
  '';
}
