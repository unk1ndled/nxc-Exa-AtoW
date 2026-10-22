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
# Runs on the frontend once the cluster is ready. Needs
# `exa-atow.apps.mpi-calculator.testFixtures = true` on the frontend.
rec {
  testDir = "/users/user1/mpi-calculator-e2e";

  testScript = ''
    frontend.succeed("systemctl start setup-mpi-calculator-test.service")
    frontend.succeed("command -v mpi-calculator")
    frontend.succeed("su - user1 -c 'cd ${testDir} && sbatch --wait mpi-calculator.sbatch'")
    frontend.succeed("grep -q '^result add = 42$' ${testDir}/mpi-calculator.out")
  '';
}
```

Each `succeed` is one step, so a failure names the step that broke. The test
checks that `mpi-calculator` is on `PATH`, then submits as `user1`; running as
root would hide ownership and login-environment mistakes.

The job has to be on shared storage before the test submits it. That fixture
belongs to the app module, behind a second option, so only the frontend of a
test composition stages it. In `apps/mpi-calculator/default.nix`, read
`testDir` from the test file and replace the `options` and `config` blocks:

```nix
let
  cfg = config.exa-atow.apps.mpi-calculator;
  inherit (import ./test.nix) testDir;

  mpiCalculator = ...; # unchanged
in
{
  options.exa-atow.apps.mpi-calculator = {
    enable = lib.mkEnableOption "the MPI calculator example";
    testFixtures = lib.mkEnableOption "staging the test job in user1's NFS home";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      exa-atow.openmpi.enable = true;
      environment.systemPackages = [ mpiCalculator ];
    })

    (lib.mkIf cfg.testFixtures {
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
          cp "${./mpi-calculator.sbatch}" "${testDir}/mpi-calculator.sbatch"
          chmod 0755 "${testDir}/mpi-calculator.sbatch"
          chown -R user1:users "${testDir}"
        '';
      };
    })
  ];
}
```

The fixture is a one-shot service. Its `RequiresMountsFor` declaration
matters: `/users` is shared by the controller, frontend, and compute nodes,
and the fixture must not run before that mount is ready.

Finally, turn on the fixture and the test in the `mpi-calculator` composition.
Add `mpiCalculatorTest = import ./apps/mpi-calculator/test.nix;` to the `let`
block at the top of `compositions.nix`, then:

```nix
mpi-calculator = topology {
  frontend.exa-atow.apps.mpi-calculator = {
    enable = true;
    testFixtures = true;
  };
  computeGroups.compute = {
    count = 2;
    node.exa-atow.apps.mpi-calculator.enable = true;
  };
  testScript = mpiCalculatorTest.testScript;
};
```

`cluster/topology.nix` runs its service and SLURM readiness checks before this script.

Now evaluate and run the first complete test layer:

```console
$ just check
$ just nxc-test mpi-calculator
```

A successful run proves that `mpi-calculator::vm` was assembled, the package
was installed, the shared directory worked, and SLURM launched one MPI rank on each compute VM.

Continue with [Create the host E2E contract](host-e2e.md).
