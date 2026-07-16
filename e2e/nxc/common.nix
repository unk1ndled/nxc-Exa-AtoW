''
  serial_stdout_off()
  ebuffer.succeed(
    "timeout 60 sh -c 'until systemctl is-active --quiet ebuffer.service; do sleep 1; done'"
  )
  ebservice.succeed(
    "timeout 60 sh -c 'until systemctl is-active --quiet ebservice.service "
    "&& eb-login >/dev/null 2>&1; do sleep 1; done'"
  )
  controller.succeed(
    "timeout 60 sh -c 'until systemctl is-active --quiet slurmctld.service; do sleep 1; done'"
  )
  compute1.succeed(
    "timeout 60 sh -c 'until systemctl is-active --quiet slurmd.service; do sleep 1; done'"
  )
  compute2.succeed(
    "timeout 60 sh -c 'until systemctl is-active --quiet slurmd.service; do sleep 1; done'"
  )
''
