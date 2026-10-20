# Test it through SLURM and NXC

Before involving the APIs, prove the calculator through the scheduler. This
chapter creates an operator-friendly batch example, then uses it in the
self-contained NXC integration test.

## 3. Make a direct SLURM example

Create `apps/mpi-calculator/mpi-calculator.sbatch`:

```bash
#!/usr/bin/env bash
#SBATCH --job-name=mpi-calculator
#SBATCH --partition=main
#SBATCH --nodes=2
#SBATCH --ntasks=2
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --time=00:02:00
#SBATCH --output=mpi-calculator.out
#SBATCH --error=mpi-calculator.err

set -euo pipefail

output=$(srun --mpi=pmix --nodes=2 --ntasks=2 --ntasks-per-node=1 \
  mpi-calculator add 19 23)

test "$(grep -c '^rank [01] operand ' <<<"$output")" -eq 2
grep -q '^rank 0 operand 19 on ' <<<"$output"
grep -q '^rank 1 operand 23 on ' <<<"$output"
grep -q '^result add = 42$' <<<"$output"
printf '%s\n' "$output"
```

The resource request matches the development cluster exactly: two nodes, two
tasks, one task per node, and one CPU per task. The compute VMs only declare
one CPU and 900 MB each, so increasing these values can leave a job pending
forever.

Assertions live in the batch script as well as in the Python validator. This
means a direct `sbatch` run fails immediately if the executable returns a
wrong result.

## 4. Add the in-topology NXC test

The NXC layer answers a focused question: after NixOS Compose has booted the
machines, can a normal frontend user submit this program through SLURM and get
a meaningful result on shared storage?

Create `apps/mpi-calculator/test.nix`:

```nix
let
  job = ./mpi-calculator.sbatch;
  testDir = "/users/user1/mpi-calculator-e2e";
in
{
  frontendModule =
    { ... }:
    {
      systemd.services.setup-mpi-calculator-test = {
        description = "Populate the MPI calculator integration-test directory";
        wantedBy = [ "multi-user.target" ];
        after = [ "remote-fs.target" ];
        unitConfig.RequiresMountsFor = "/users";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          rm -rf "${testDir}"
          mkdir -p "${testDir}"
          cp "${job}" "${testDir}/mpi-calculator.sbatch"
          chmod 0755 "${testDir}/mpi-calculator.sbatch"
          chown -R user1:users "${testDir}"
        '';
      };
    };

  testScript = ''
    frontend.succeed(
      "set -eu; "
      "systemctl start setup-mpi-calculator-test.service; "
      "command -v mpi-calculator >/dev/null; "
      "su - user1 -c 'cd ${testDir} && sbatch --wait mpi-calculator.sbatch'; "
      "test -s ${testDir}/mpi-calculator.out; "
      "grep -q '^result add = 42$' ${testDir}/mpi-calculator.out"
    )
  '';
}
```

The `frontendModule` creates a one-shot fixture service. Its
`RequiresMountsFor` declaration matters: `/users` is shared by the controller,
frontend, and compute nodes, and the fixture must not run before that mount is
ready.

The test checks that `mpi-calculator` is on `PATH`, then submits as `user1`;
running as root would hide ownership and login-environment mistakes.

There is nothing to register. `topology.nix` runs its service and SLURM
readiness checks before this script, and the NXC VM-driver workarounds after it.

Now evaluate and run the first complete test layer:

```console
$ just check
$ just nxc-test mpi-calculator
```

A successful run proves that `mpi-calculator::vm` was assembled, the package
was installed, the shared directory worked, and SLURM launched one MPI rank on each compute VM.

Continue with [Create the host E2E contract](host-e2e.md).
