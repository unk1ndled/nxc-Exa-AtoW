# Run, debug, and adapt the workload

The package and both test contracts are now registered. This final chapter
runs the complete user-facing path, explains the expected evidence, and gives
you a checklist for adapting the example to a real application.

## 8. Run the complete path

First run the self-contained NXC validation if you have not already:

```console
$ just nxc-test mpi-calculator
```

Then start a persistent matching deployment:

```console
$ just up vm mpi-calculator
```

Leave it running. In a second terminal, launch the host test:

```console
$ just test mpi-calculator
```

The tunnel helper forwards ebuffer on port 8000, ebservice on port 8001, and
frontend SSH on port 2222. The test should finish with output resembling:

```text
E2E passed: API -> runtime -> two-node SLURM -> MPI calculator
19 + 23 = 42 across compute1, compute2
Scheduler job:     1
Scheduler ebuffer: <uuid> (COMPLETED, exit 0:0)
Output ebuffer:    <uuid> (<size> bytes)
Returned mpi-calculator.out:
rank 0 operand 19 on compute1
rank 1 operand 23 on compute2
result add = 42
```

Job IDs, UUIDs, output sizes, and the mapping of ranks to compute host names
will vary. The important facts are a successful terminal SLURM record, the
result 42, ranks 0 and 1, and two distinct hosts.

Return to the first terminal and press Ctrl-C to stop the VM deployment. NXC's
VM flavour has no standalone cleanup, so `just down` does not stop VMs.

## 9. Debug the first failures

The two test layers fail at different boundaries, and that is useful. Start
with the first failing layer instead of debugging the whole service path at
once.

| Symptom | Likely cause and first place to look |
| --- | --- |
| Flake evaluation reports that `exa-atow.apps.mpi-calculator` does not exist | `apps/default.nix` does not import `./mpi-calculator`. |
| `command -v mpi-calculator` fails | The node does not set `exa-atow.apps.mpi-calculator.enable = true` in `compositions.nix`, or the package is not in `environment.systemPackages` in `apps/mpi-calculator/default.nix`. |
| `setup-mpi-calculator-test.service` does not exist | The frontend does not set `exa-atow.apps.mpi-calculator.testFixtures = true`. |
| The SLURM job stays pending | The request exceeds the VM resources, or a compute daemon is not ready. Inspect `squeue`, `scontrol show job <id>`, and `sinfo` on the frontend. |
| `srun` reports an MPI or PMIx error | Confirm `--mpi=pmix`, `exa-atow.openmpi.enable = true` in the app module, and the default `QEMU_OPTS=-cpu host` path. |
| SLURM completes but the host E2E cannot return output | `output_name`, the path written by `scheduler_core`, and `diagnostic_files` must use the same filename. |
| The host validator sees only one host | Check `nodes = 2`, `tasks = 2`, and `--ntasks-per-node=1` in every resource declaration. |
| The host E2E cannot connect or tests the wrong binary | Only one deployment can own ports 8000, 8001, and 2222. Keep a matching `just up vm mpi-calculator` running and rerun `just test mpi-calculator`. |

On a host-E2E failure, read the diagnostics printed before cleanup. The shared
lifecycle tails the main SLURM output and error files plus every filename in
`diagnostic_files`. Adding the application's own log there is often the
fastest way to turn a generic pipeline failure into a useful scientific error.

## 10. Review the change as a workload contract

Before committing, the new app should have these files:

| Concern | File |
| --- | --- |
| Source | `apps/mpi-calculator/mpi-calculator.c` |
| Nix package, runtime, and test fixture | `apps/mpi-calculator/default.nix` |
| Direct scheduler job | `apps/mpi-calculator/mpi-calculator.sbatch` |
| NXC assertions | `apps/mpi-calculator/test.nix` |
| Module import | `apps/default.nix` |
| Composition | `mpi-calculator` in `compositions.nix` |

If you also use the optional host client:

| Concern | File |
| --- | --- |
| Host resource contract | `clients/python-e2e/mpi-calculator-job.ini` |
| Host behavior contract | `clients/python-e2e/mpi_calculator_e2e.py` |
| Host dispatcher | Import and entry in `clients/python-e2e/minimal-e2e.py` |

Finish with:

```console
$ just check
$ just nxc-test mpi-calculator
# with `just up vm mpi-calculator` active in another terminal
$ just test mpi-calculator
```

If the change affects shared MPI configuration, SLURM resources, shared
storage, tunnels, the API services, or `clients/python-e2e/common.py`, also run both existing
workloads when practical. Shared infrastructure can pass the calculator while
breaking a file-heavy scientific application such as OpenQCD.

## When your real application is larger

The calculator keeps source beside its Nix module, which is convenient for a
small demonstrator. A real application can instead use a pinned Nix package,
an overlay package, or a derivation that fetches a released source archive.
Keep the same boundary: package and runtime settings belong under
`apps/<name>/`, not in `cluster/topology.nix`.

Likewise, replace the fixed operands with representative input files and
validate scientific meaning rather than only process exit status. Good E2E
assertions answer questions a user cares about: Was the intended problem
loaded? Did every required rank participate? Did the solver converge? Is the
returned value finite and within its physical range? Was the expected output
artifact actually returned through the API?

That is the reusable pattern demonstrated here: package the application,
prove it inside the topology, then prove the complete user-facing service
path with an application-specific contract.
